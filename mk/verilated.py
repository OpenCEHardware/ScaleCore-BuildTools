from .deps import Package, PkgconfigPackage
from .rtl import RtlPackage

__all__ = [
    'VerilatedPackage',
    'VerilatedRunPackage',
    ]

class VerilatedPackage(RtlPackage):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self._pkgconfig = set()
        self._make_trace_args = None

    def main(self, paths):
        self._main.add(paths)

    def executable(self, name=None):
        self._verilator_executable = name or self._name()

    def trace_args(self, make_trace_args):
        self._make_trace_args = make_trace_args

    def setup_outputs(self):
        self.check_assert(self._verilator_executable, 'must call .executable()')
        super().setup_outputs(target='vl')

    def link_dependency(self, dependency):
        if isinstance(dependency, PkgconfigPackage):
            self._pkgconfig.add(dependency.name())
        else:
            super().link_dependency(dependency)

    def print_vars(self):
        if not self._verilator_executable:
            self.executable()

        super().print_vars()

        self.check_assert(not self._main.empty(),
                          f'must add at least one main .cpp file with .main()')

        self.core_var('vl_pkgconfig', self._pkgconfig)

class VerilatedRunPackage(Package):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self._args = []
        self._runner = None

    def runner(self, runner):
        self._runner = runner

    def args(self, args):
        self._args.extend(args)

    def setup_outputs(self):
        self.check_assert(self._runner, 'missing runner, call .runner()')
        self.requires(self._runner)

        self._runner = self._runner.resolve()
        self.check_assert(isinstance(self._runner, VerilatedPackage), 'runner must be a VerilatedPackage')

        self.add_outputs(['stdout.$(seed_name).txt'])
        super().setup_outputs(target='sim')

    def link_dependency(self, dependency):
        # Allow any package as a dependency by simply requiring all of its output
        self.requires(dependency, outputs=dependency.outputs())

    def print_vars(self):
        super().print_vars()

        if self._runner._make_trace_args and self.make_flags.trace:
            extension = 'fst' if self.make_flags.fst else 'vcd'
            basename = f'dump.$(seed_name)'
            filename = f'{basename}.{extension}'

            self._args = self._runner._make_trace_args(filename) + self._args
            self.core_var('vl_run_dump', basename)

        self.core_var('vl_run_exe', self._runner._verilator_executable)
        self.core_var('vl_run_args', self._args)
