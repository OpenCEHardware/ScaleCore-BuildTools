class Makefile:
    def __init__(self, filename):
        self._file = open(filename, 'w')

    def __enter__(self):
        self._file.__enter__()
        return self

    def __exit__(self, ty, value, traceback):
        return self._file.__exit__(ty, value, traceback)

    def var(self, name, values, *, lazy=False):
        if type(values) is str:
            values = (values,)

        token = '=' if lazy else ':='
        print(name, token, *(value.strip().replace('\n', '$(newline)') for value in values), file=self._file)

    def rule(self, targets, prerequisites, *, order_only=(), recipe='', grouped=False, silent=False):
        if type(targets) is str:
            targets = (targets,)

        if type(prerequisites) is str:
            prerequisites = (prerequisites,)

        if type(order_only) is str:
            order_only = (order_only,)

        if not targets or (not prerequisites and not order_only and not recipe):
            return

        separator = '&:' if grouped else ':'

        if order_only:
            print(*targets, separator, *prerequisites, '|', *order_only, file=self._file)
        else:
            print(*targets, separator, *prerequisites, file=self._file)

        self.recipe(recipe, silent=silent)

    def recipe(self, text, *, silent=False):
        sigil = '@' if silent else ''
        for line in text.splitlines():
            print('\t', sigil, line, sep='', file=self._file)
