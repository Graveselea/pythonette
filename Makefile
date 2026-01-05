PYTHON ?= python3
PIP ?= $(PYTHON) -m pip

ROOT := ..

.PHONY: help install-dev check lint types docs precommit

help:
        @echo "Targets:"
        @echo "  make install-dev   Install dev tools"
        @echo "  make check         Run all checks"
        @echo "  make lint          flake8"
        @echo "  make types         mypy"
        @echo "  make docs          pydocstyle"

install-dev:
        $(PIP) install -r requirements-dev.txt

check: lint types docs
        @echo "All checks passed ✅"

lint:
        cd $(ROOT) && flake8 . --config tests_PYTHON/.flake8

types:
        cd $(ROOT) && mypy . --config-file tests_PYTHON/mypy.ini

docs:
        cd $(ROOT) && pydocstyle . --config tests_PYTHON/.pydocstyle

precommit:
        pre-commit install --config tests_PYTHON/.pre-commit-config.yaml