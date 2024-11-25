import os.path

from .deps import Fileset, find_files
from .rtl import RtlPackage

__all__ = [
    'CocotbTestPackage',
    ]

class CocotbTestPackage(RtlPackage):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, verilator_executable='run-test')

        self._cocotb_modules = []
        self._cocotb_files = Fileset()
        self._cocotb_paths = Fileset()

    def cocotb_modules(self, modules):
        if type(modules) is str:
            modules = (modules,)

        self._cocotb_modules.extend(modules)

    def cocotb_paths(self, paths):
        assert type(paths) is list

        self._cocotb_paths.add(paths)
        self._cocotb_files.add(find_files(os.path.join(base_dir, '**', '*.py') for base_dir in paths))

    def setup_outputs(self):
        self.requires(self._cocotb_files)
        self._require_rtl_top()

        self.add_outputs([f'html/{module}.html' for module in self._cocotb_modules] + ['results.$(seed_name).xml'])
        super().setup_outputs(target='cocotb')

    def print_vars(self):
        super().print_vars()

        self.check_assert(not self._cocotb_paths.empty(),
                          f'must call .cocotb_paths() with at least one path')

        self.check_assert(self._cocotb_modules,
                          f'must call .cocotb_modules() with at least one Python module name')

        self.core_var('cocotb_paths', self._cocotb_paths)
        self.core_var('cocotb_modules', self._cocotb_modules)
