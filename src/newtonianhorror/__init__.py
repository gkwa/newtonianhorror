import sys

from . import main2

__project_name__ = "newtonianhorror"


def main() -> int:
    out = main2.render_template("extended.j2")
    sys.stdout.write(out)
    return 0
