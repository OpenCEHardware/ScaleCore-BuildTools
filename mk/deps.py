import glob, hashlib, importlib.util, os.path, re, sys

__all__ = [
    'Fileset',
    'Package',
    'add_subdir',
    'find_files',
    'find_package',
    'find_pkgconfig',
    ]

_deps = None

class Dependencies:
    def __init__(self):
        self.all_refs = []
        self.all_packages = {}

        self.makefile = None
        self.make_flags = {}

        self.subdir_path = '.'
        self.subdir_stack = []

        self.definitions_ready = False

        self.output_dirs = {}
        self.copied_files = {}
        self.linked_files = {}

        self.mk_files = set()

    def set_global(self):
        global _deps
        assert _deps is None
        _deps = self

    def add_output_dir(self, directory):
        if directory not in self.output_dirs:
            parent = os.path.dirname(directory)
            if parent:
                self.add_output_dir(parent)
                self.output_dirs[parent].add(directory)

            self.output_dirs[directory] = set()

# Order-preserving collection of source or output files
class Fileset:
    def __init__(self, *, files=None, globs=None, exclude=None, skip_checks=False):
        if files is None:
            files = set()
        elif type(files) not in (set, list):
            files = set(files)

        if globs is None:
            globs = set()

        if exclude is None:
            exclude = set()

        assert type(globs) is set and type(exclude) is set

        if not skip_checks:
            assert globs or not files, f'created non-empty fileset from empty set of globs'

        if type(files) is list:
            self._files = [file for file in files if file not in exclude]
        else:
            self._files = sorted(files.difference(exclude))

        for file_path in files:
            assert ' ' not in file_path, \
                f'whitespace in paths is forbidden: {repr(file_path)}'

        self._globs = globs
        self._exclude = exclude

    def __iter__(self):
        return iter(self._files)

    def copy(self):
        other = Fileset()
        other._files = self._files.copy()
        other._globs = self._globs.copy()
        other._execlude = self._exclude.copy()
        return other

    def empty(self):
        return not self._files

    def add(self, other):
        other = find_files(other)

        old_files = self._files
        self._files = self._files.copy()
        self._files.extend(file for file in other._files if file not in old_files)

        self._globs.update(other._globs)
        self._exclude.update(other._exclude)

    def prepend(self, other):
        other = find_files(other)

        old_files = self._files
        self._files = other._files.copy()
        self._files.extend(file for file in old_files if file not in other._files)

        self._globs.update(other._globs)
        self._exclude.update(other._exclude)

    def take(self, other):
        other = find_files(other)

        if not all(file in self._files for file in other._files):
            raise ValueError(f'set {repr(other._files)} is not a subset of {repr(self._files)}')

        self._files = [file for file in self._files if file not in other._files]
        self._exclude.update(other._files)

        return other
    def expect_single(self):
        if len(self._files) == 1:
            return self._files[0]

        return None

class Package:
    _NAME_REGEX = re.compile('[a-zA-Z][a-zA-Z0-9_]*')

    def __init__(self, name, *, abstract=False, can_symlink=True):
        global _deps

        assert Package._NAME_REGEX.match(name), f'illegal package name: {name}'


        self._name = name
        self._target = None
        self._requires = set()

        self._outputs = []

        self._tested_flags = set()
        self._file_prerequisites = Fileset()

        self._build_dir = None
        self._can_symlink = can_symlink
        self._build_id_hash = None

        if abstract:
            self._path = None
        elif not _deps.subdir_stack:
            self._path = name
        elif name == os.path.basename(_deps.subdir_path):
            self._path = _deps.subdir_path
        else:
            self._path = os.path.join(_deps.subdir_path, name)

        self.make_flags = MakeFlagsProxy(self)

        if _deps.definitions_ready:
            raise Exception(f'attempt to define package {repr(name)} after all references have been resolved')
        elif name in _deps.all_packages:
            raise ValueError(f'multiple definitions of package {repr(name)}')

        _deps.all_packages[name] = self

    def name(self):
        return self._name

    def path(self):
        return self._path

    def target(self):
        return self._target

    def resolve(self):
        return self

    def requires(self, other, *, outputs=None):
        if isinstance(other, (str, list)):
            other = find_files(other)

        assert isinstance(other, (Package, PackageRef, Fileset)), \
            f'argument to Package.requires() has type {type(other)}, expecting Package, PackageRef or Fileset'

        if isinstance(other, Fileset):
            assert outputs is None, f'the \'outputs\' argument to Package.requires() is unsupported for Fileset dependencies'

        for output in outputs if outputs is not None else (None,):
            self._requires.add((other, output))

    def dependencies(self):
        return {dep.resolve() for dep, output in self._requires if isinstance(dep, (Package, PackageRef)) and not output}

    def add_outputs(self, outputs):
        assert type(outputs) is list
        self._outputs.extend(check_safe_path(output) for output in outputs)

    def outputs(self):
        return iter(self._outputs)

    def setup_outputs(self, *, target=None):
        global _deps

        self._target = target
        assert target is not None or self._path is None

        if not target:
            return

        tested_flags = set()
        for package in self.walk_deps():
            tested_flags.update(package._tested_flags)

        enable = sorted(flag for flag in tested_flags if _deps.make_flags[flag])
        disable = sorted(flag for flag in tested_flags if not _deps.make_flags[flag])

        build_id_vars = [
            ('path',    self._path),
            ('name',    self._name),
            ('target',  self._target),
            ('enable',  ','.join(enable)),
            ('disable', ','.join(disable)),
        ]

        build_id_text = ';'.join(f'{key}={value}' for key, value in build_id_vars)
        self._build_id_hash = hashlib.sha1(build_id_text.encode('ascii')).hexdigest()[:8]

        build_id_tag = '-'.join(enable) if enable else 'none'
        build_id = f'{self._build_id_hash}-{build_id_tag}'

        self._build_dir = os.path.join('$(O)', self._name, build_id)


    def link_requires(self):
        for required, output in self._requires.copy():
            if output or isinstance(required, Fileset):
                continue

            self.link_dependency(required.resolve())

        for required, output in self._requires:
            if isinstance(required, Fileset):
                self._file_prerequisites.add(self.copy_sources(required))
            elif output:
                required = required.resolve()

                self.check_assert(output in required._outputs,
                                  f'{repr(output)} has not been declared as an output of package {repr(required.name())}')

                self._file_prerequisites.add(self.unveil([(os.path.join(required._build_dir, output), output)]))

    def link_dependency(self, required):
        self.check_assert(
            False,
            f'cannot make a {type(self).__name__} depend on a {type(required).__name__} ({repr(required._name)})')

    def check_assert(self, condition, message):
        if not condition:
            raise ValueError(f'in package {repr(self._name)}: {message}')

    def copy_sources(self, paths):
        return self.unveil((path, path) for path in find_files(paths))

    def copy_outputs(self, package):
        return self.unveil((os.path.join(package._build_dir, output), output) for output in package.outputs())

    def copy_object(self, package, source, dest):
        return self.unveil([(os.path.join(package._build_dir, source), dest)])

    def unveil(self, source_dest_pairs):
        global _deps

        if self._can_symlink:
            target_dict = _deps.linked_files
        else:
            target_dict = _deps.copied_files

        files = []
        for source, dest in source_dest_pairs:
            dest_relative = check_safe_path(dest)
            dest = os.path.join(self._build_dir, dest_relative)

            _deps.add_output_dir(os.path.dirname(dest))

            existing = target_dict.get(dest) or ''
            self.check_assert(not existing or existing == source,
                              f'conflicting entries for output path {repr(dest)}: {repr(existing)} and {repr(source)}')

            target_dict[dest] = source
            files.append(dest_relative)

        return Fileset(files=files, skip_checks=True)

    def walk_deps(self, *, popped=None, filter_package=lambda package: True):
        if popped is None:
            popped = set()

        for required, output in self._requires:
            if not isinstance(required, (Package, PackageRef)):
                continue

            package = required.resolve()
            if package in popped:
                continue

            popped.add(package)
            if filter_package(package):
                yield from package.walk_deps(popped=popped, filter_package=filter_package)
                yield package

        if self not in popped and filter_package(self):
            popped.add(self)
            yield self

    def walk_filesets(self, filter_package, map_package):
        result = Fileset()

        for package in self.walk_deps(filter_package=filter_package):
            mapped = map_package(package).copy()
            mapped.prepend(result)
            result = mapped

        return result

    def print_vars(self):
        global _deps

        if not self._path:
            return

        self.core_var('obj', self._build_dir)
        self.core_var('path', self._path)
        self.core_var('target', self._target)
        self.core_var('outputs', self._outputs)
        self.core_var('build_id', self._build_id_hash)
        self.core_var('obj_deps', self._file_prerequisites)

    def print_targets(self):
        global _deps
        assert _deps.definitions_ready

    def core_var(self, var, value, *, lazy=False):
        global _deps
        if value and (not isinstance(value, Fileset) or not value.empty()):
            _deps.makefile.var(f'core_info/{self._name}/{var}', value, lazy=lazy)

class MakeFlagsProxy:
    def __init__(self, package):
        self._package = package

    def __getattr__(self, flag):
        global _deps

        value = _deps.make_flags.get(flag)
        if value is not None:
            self._package._tested_flags.add(flag)
            return value

        raise AttributeError(f'unknown make flag {repr(flag)}')

class PkgconfigPackage(Package):
    _all = {}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, abstract=True)
        PkgconfigPackage._all[self.name()] = self

class PackageRef:
    def __init__(self, name):
        global _deps

        self._name = name
        self._package = None

        if _deps.definitions_ready:
            self.resolve()

        _deps.all_refs.append(self)

    def name(self):
        return self._name

    def resolve(self):
        global _deps

        if not self._package:
            self._package = _deps.all_packages.get(self._name)
            if not self._package:
                raise ValueError(f'reference to undefined package {repr(self._name)}')

        return self._package

def add_subdir(path):
    global _deps

    if path is None:
        assert not _deps.subdir_stack, f'\'path\' is None but subdir_stack is not empty'
    else:
        path = check_safe_path(path)

        _deps.subdir_path = os.path.join(_deps.subdir_path, path) if _deps.subdir_stack else path
        _deps.subdir_stack.append(path)

        assert ' ' not in _deps.subdir_path, \
            f'whitespace is forbidden in paths: {repr(_deps.subdir_path)}'

    try:
        module_name = '.'.join(['mk', 'src'] + [x for x in _deps.subdir_path.split(os.path.sep) if x])
        module_path = os.path.join(_deps.subdir_path, 'mk.py')

        spec = importlib.util.spec_from_file_location(module_name, module_path)
        module = importlib.util.module_from_spec(spec)

        _deps.mk_files.add(module_path)

        sys.modules[module_name] = module
        spec.loader.exec_module(module)
    finally:
        if path is not None:
            _deps.subdir_stack.pop()
            _deps.subdir_path = os.path.join(*_deps.subdir_stack) if _deps.subdir_stack else '.'

def check_safe_path(path):
    path = os.path.normpath(path)

    assert not os.path.isabs(path), f'Forbidden absolute path: {repr(path)}'
    assert '..' not in path.split(os.path.sep), f'Forbidden directory traversal: {repr(path)}'

    return path

def find_files(paths, *, root=None, exclude=None, allow_unmatched=False):
    global _deps

    if isinstance(paths, Fileset):
        assert root is None and exclude is None
        return paths

    if type(paths) is str:
        paths = (paths,)

    paths = [check_safe_path(path) for path in paths]

    if root is None:
        root = _deps.subdir_path

    root = check_safe_path(root)
    root_repr = os.path.abspath(root)

    files = set()

    for path in paths:
        matches = set(os.path.join(root, match) for match in glob.glob(path, root_dir=root, recursive=True))
        if not allow_unmatched and not matches and '*' not in path:
            raise FileNotFoundError(f'path {repr(path)} not found within {repr(root_repr)}')

        files.update(matches)

    if not allow_unmatched and paths and not files:
        raise FileNotFoundError(f'no matches found for any glob pattern from {repr(paths)} within {repr(root_repr)}')

    return Fileset(files=files, globs=set(paths), exclude=exclude)

def find_package(name):
    return PackageRef(name)

def find_pkgconfig(name):
    if name not in PkgconfigPackage._all:
        PkgconfigPackage(name)

    return find_package(name)
