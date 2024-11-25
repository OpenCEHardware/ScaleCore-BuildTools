import argparse, os.path

from .deps import Dependencies, add_subdir
from .makefile import Makefile

parser = argparse.ArgumentParser(description='Generates makefile rules from mk.py scripts')

parser.add_argument('--source', help='absolute source directory path', required=True)
parser.add_argument('--output', help='output directory', required=True)
parser.add_argument('--enable', help='enabled make flags', required=True)
parser.add_argument('--disable', help='disabled make flags', required=True)

args   = parser.parse_args()
output = os.path.normpath(args.output)

assert os.path.isabs(args.source)

assert ' ' not in args.source, \
    f'whitespace in paths is forbidden: {repr(args.source)}'

deps = Dependencies()
deps.set_global()

flag_dict = lambda arg, value: {flag: value for flag in arg.split(',')}

deps.make_flags = flag_dict(args.enable, True)
deps.make_flags.update(flag_dict(args.disable, False))

add_subdir(None)
add_subdir('mk/builtin')

try:
    for ref in deps.all_refs:
        ref.resolve()
finally:
    deps.definitions_ready = True

for package in deps.all_packages.values():
    package.setup_outputs()

for package in deps.all_packages.values():
    package.link_requires()

os.makedirs(output, exist_ok=True)

tmp_out_path = os.path.join(output, 'db-tmp.mk')
with Makefile(tmp_out_path) as makefile:
    deps.makefile = makefile

    makefile.var('last_src', args.source)
    makefile.var('all_cores', (name for name, package in deps.all_packages.items() if package.path()))

    makefile.rule('$(db_mk)', deps.mk_files)

    for package in deps.all_packages.values():
        package.print_vars()

    for package in deps.all_packages.values():
        package.print_targets()

    for dest, source in deps.copied_files.items():
        makefile.rule(dest, source, order_only=os.path.dirname(dest))

    for dest, source in deps.linked_files.items():
        makefile.rule(dest, source, order_only=os.path.dirname(dest))

    for parent, subdirs in deps.output_dirs.items():
        makefile.rule(subdirs, (), order_only=parent)

    makefile.rule(deps.copied_files.keys(), (), recipe='cp -LT -- "$<" "$@"', silent=True)
    makefile.rule(deps.linked_files.keys(), (), recipe='ln -LTsfr -- "$<" "$@"', silent=True)
    makefile.rule(deps.output_dirs.keys(), (), recipe='mkdir -- "$@"', silent=True)

os.rename(tmp_out_path, os.path.join(output, 'db.mk'))
