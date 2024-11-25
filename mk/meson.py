from .deps import Fileset, Package

__all__ = [
    'MesonPackage',
    ]

class MesonPackage(Package):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._meson_src = Fileset()
        self._meson_args = []

    def meson_src(self, paths):
        self._meson_src.add(paths)

    def meson_args(self, args):
        self._meson_args.extend(args)

    def setup_outputs(self):
        super().setup_outputs(target='meson')

    def print_vars(self):
        super().print_vars()

        self.check_assert(self._meson_src, 'must provide meson_src')
        self.copy_sources(self._meson_src)

        self.core_var('meson_src', self._meson_src)
        self.core_var('meson_args', self._meson_args, lazy=True)
