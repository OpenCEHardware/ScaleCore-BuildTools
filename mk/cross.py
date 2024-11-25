from .deps import Fileset, Package

__all__ = [
    'CrossSoftwarePackage',
    ]

class CrossSoftwarePackage(Package):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._cross = None
        self._cc_files = Fileset()
        self._cc_flags = []
        self._ld_flags = []
        self._executable = None
        self._static_lib = None

    def cross_triplet(self, triplet):
        self._cross = triplet

    def cc_files(self, paths):
        self._cc_files.add(paths)

    def cc_flags(self, args):
        assert type(args) is list
        self._cc_flags.extend(args)

    def ld_flags(self, args):
        assert type(args) is list
        self._ld_flags.extend(args)

    def executable(self, name=None):
        self._executable = name or self.name()

    def static_lib(self, name=None):
        self._static_lib = name or f'lib{self.name()}.a'
        self.check_assert(self._static_lib.startswith('lib') and self._static_lib.endswith('.a'),
                          f'static_lib() name must follow the pattern \'libname.a\'')

    def setup_outputs(self):
        self.make_flags.opt

        self.check_assert(bool(self._executable) != bool(self._static_lib),
                          'must call exactly one of .executable() or .static_lib()')

        if self._executable:
            self.add_outputs([self._executable, f'{self._executable}.bin', f'{self._executable}.hex'])

        if self._static_lib:
            self.add_outputs([self._static_lib])

        super().setup_outputs(target='cross')

    def link_dependency(self, dependency):
        if not isinstance(dependency, CrossSoftwarePackage):
            return super().link_dependency(dependency)

        self.check_assert(not dependency._executable,
                          f'cannot link against executable {repr(dependency.name())} as if it were a library')

    def print_vars(self):
        super().print_vars()

        cc_files = self._cc_files.copy()
        self.copy_sources(cc_files)

        for package in self.dependencies():
            package = package.resolve()
            if isinstance(package, CrossSoftwarePackage) and package._static_lib:
                cc_files.add(self.copy_outputs(package))

        self.core_var('cc_files', cc_files)
        self.core_var('cc_flags', self._cc_flags, lazy=True)
        self.core_var('ld_flags', self._ld_flags, lazy=True)

        if self._executable:
            self.core_var('ld_binary', self._executable)

        if self._static_lib:
            self.core_var('ar_lib', self._static_lib)

        if self._cross:
            self.core_var('cross', f'{self._cross}-')
