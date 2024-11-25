from .rtl import RtlPackage

__all__ = [
    'SystemVerilogTestPackage',
    ]

class SystemVerilogTestPackage(RtlPackage):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, verilator_executable='run-test')

    def main(self, paths):
        self._main.add(paths)

    def setup_outputs(self):
        self.add_outputs(['stdout.$(seed_name).txt'])
        super().setup_outputs(target='vl')
