EMACS ?= emacs
PYTHON := $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)

.PHONY: setup export check test-python test-emacs check-byte-compile

setup:
	python3 -m venv .venv
	.venv/bin/python -m pip install -r requirements.txt

export:
	@test -n "$(PROJECT)" || { echo 'usage: make export PROJECT=/path/to/project' >&2; exit 2; }
	ENGDOC_PROJECT_DIRECTORY="$(abspath $(PROJECT))" \
		$(EMACS) -Q --batch -L . -l engdoc -f engdoc-batch-export

check: test-python test-emacs check-byte-compile

test-python:
	$(PYTHON) -m unittest discover -s test -p 'test_*.py' -v

test-emacs:
	$(EMACS) -Q --batch -L . -L documents/project -L documents/requirements -L documents/design -L documents/acceptance -L documents/calibration -L documents/risk -L documents/installation -L documents/service-manual -L documents/user-manual \
		-l test/engdoc-tests.el -f ert-run-tests-batch-and-exit

check-byte-compile:
	$(EMACS) -Q --batch -L . -L documents/project -L documents/requirements -L documents/design -L documents/acceptance -L documents/calibration -L documents/risk -L documents/installation -L documents/service-manual -L documents/user-manual \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile engdoc.el documents/project/*.el documents/requirements/*.el documents/design/*.el documents/acceptance/*.el documents/calibration/*.el documents/risk/*.el documents/installation/*.el documents/service-manual/*.el documents/user-manual/*.el
	@find . -name '*.elc' -delete
