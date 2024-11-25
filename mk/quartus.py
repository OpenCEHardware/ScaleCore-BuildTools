import os.path

from .deps import Fileset
from .rtl import RtlPackage

__all__ = [
    'QuartusProjectPackage',
    'QuartusQsysLibraryPackage',
    ]

class QuartusProjectPackage(RtlPackage):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, can_symlink=False)
        self._altera_device = None
        self._altera_family = None
        self._qsf = Fileset()
        self._qsys_platforms = Fileset()
        self._sdc = Fileset()

    def altera_device(self, device):
        self._altera_device = device

    def altera_family(self, family):
        self._altera_family = family

    def qsf(self, paths):
        self._qsf.add(paths)

    def qsys_platform(self, paths):
        self._qsys_platforms.add(paths)

    def sdc(self, paths):
        self._sdc.add(paths)

    def setup_outputs(self):
        top = self._require_rtl_top()
        if self.make_flags.synthesis:
            self.add_outputs([f'{top}.sof'])
        else:
            self.add_outputs([f'{top}.qpf'])

        super().setup_outputs(target='quartus')

    def link_dependency(self, dependency):
        if isinstance(dependency, QuartusQsysLibraryPackage):
            pass
        else:
            super().link_dependency(dependency)

    def print_vars(self):
        super().print_vars()

        self.copy_sources(self._sdc)
        self.copy_sources(self._qsf)
        self.copy_sources(self._qsys_platforms)

        self.core_var('altera_device', self._altera_device)
        self.core_var('altera_family', self._altera_family)

        self.core_var('sdc_files', self._sdc)
        self.core_var('qsf_files', self._qsf)
        self.core_var('qsys_platforms', self._qsys_platforms)

        qsys_deps = Fileset()
        for package in self.dependencies():
            if not isinstance(package, QuartusQsysLibraryPackage):
                continue

            tcl_file = package._hw_tcl.expect_single()
            self.check_assert(tcl_file, f'package {repr(package.name())} does not declare exactly one hw_tcl() file')

            basename = os.path.basename(tcl_file)
            self.core_var(f'rtl_top/{basename}', package._require_rtl_top())
            self.core_var(f'rtl_files/{basename}', package._all_rtl(copy_to=self))

            qsys_deps.add(package._hw_tcl)

        self.copy_sources(qsys_deps)
        self.core_var(f'qsys_deps', qsys_deps)

class QuartusQsysLibraryPackage(RtlPackage):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, abstract=True)
        self._hw_tcl = Fileset()

    def hw_tcl(self, paths):
        self._hw_tcl.add(paths)
