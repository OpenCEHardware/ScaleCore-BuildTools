import os.path

from .deps import Fileset, Package, find_package

__all__ = [
    'RdlPackage',
    ]

_CPU_INTERFACES = {
    'apb3',       'apb3-flat',
    'apb4',       'apb4-flat',
    'axi4-lite',  'axi4-lite-flat',
    'avalon-mm',  'avalon-mm-flat',
    'passthrough',
    }

class RdlPackage(Package):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._rdl = Fileset()
        self._top = None
        self._args = []
        self._cpu_intf = None
        self._regblock_rtl = None

    def rdl(self, paths):
        self._rdl.add(paths)

    def top(self, top_component=None):
        self._top = top_component or self.name()

    def args(self, args):
        self._args.extend(args)

    def cpu_interface(self, interface):
        if interface not in _CPU_INTERFACES:
            raise ValueError(f'bad CPU interface regblock for regblock: {repr(interface)}, must be one of {repr(_CPU_INTERFACES)}')

        self._cpu_intf = interface

    def setup_outputs(self):
        out = os.path.join('regblock', self.name())
        self._regblock_rtl = [os.path.join(out, f'{self._top}_pkg.sv'), os.path.join(out, f'{self._top}.sv')]

        self.add_outputs(self._regblock_rtl)
        super().setup_outputs(target='regblock')

    def print_vars(self):
        super().print_vars()

        self.copy_sources(self._rdl)

        self.core_var('regblock_rdl', self._rdl)
        self.core_var('regblock_top', self._top)
        self.core_var('regblock_args', self._args)
        self.core_var('regblock_cpuif', self._cpu_intf)
