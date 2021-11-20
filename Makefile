# all the recipes are phony (no files to check).
.PHONY: .check-env-vars .deps docs tests build dev run update install-local run-local deploy deploy-twine help
.DEFAULT_GOAL := help

IS_LINUX_OS := $(shell uname -s | grep -c Linux)
# IS_POETRY := $(shell command -v poetry  2> /dev/null)
IS_POETRY := $(shell pip freeze | grep "poetry==")
IS_TWINE := $(shell pip freeze | grep "twine==")


export PATH := ${HOME}/.local/bin:$(PATH)

help:
	@echo "Please use 'make <target>' where <target> is one of"
	@echo ""
	@echo "  build             builds the app in Docker"
	@echo "  dev               runs the app with docker-compose.dev"
	@echo "  run-local         runs the app locally"
	@echo "  poetry-update     updates the dependencies in poetry.lock"
	@echo "  poetry-install    installs the dependencies"
	@echo "  tests             run all the tests"
	@echo "  reformat          reformats the code, using Black"
	@echo "  flake8            flakes8 the code"
	@echo "  deploy            deploys the project using Poetry (not recommended, only use if relly needed)"
	@echo "  deploy-twine      deploys the project using Twine (not recommended, only use if relly needed)"
	@echo ""
	@echo "Check the Makefile to know exactly what each target is doing."


.check-os:
    # The @ is to surpress the output of the evaluation
	@if [ ${IS_LINUX_OS} -eq 0 ]; then echo "This Recipe is not available in non-Linux Systems"; exit 3; fi

.check-env-vars:
	@test $${PYPI_USER?Please set environment variable PYPI_USER}
	@test $${PYPI_PASS?Please set environment variable PYPI_PASS}

.deps:
	@if [ -z ${IS_POETRY} ]; then pip install poetry; fi
	@if [ -z ${IS_TWINE} ]; then pip install twine; fi

docs:
	# poetry run sphinx-build -b html docs/source docs/build

tests: .check-os
	poetry run pytest -vv tests

build: .check-env-vars
	docker-compose build

dev: .check-env-vars
    # the dev file apply changes to the original compose file
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

run: build
	docker-compose up

poetry-config: .check-env-vars
	# For external packages, poetry saves metadata
	# in it's cache which can raise versioning problems, if the package
	# suffered version support changes. Thus, we clean poetry cache
	yes | poetry cache clear --all mqtt_api
	poetry config http-basic.pypi-switch ${PYPI_USER} ${PYPI_PASS}

poetry-update: poetry-config
	poetry update

poetry-install: poetry-update
	poetry install

run-local:
	python slac/main.py

mypy:
	mypy --config-file mypy.ini slac tests

reformat:
	isort slac tests && black --exclude --line-length=88 slac tests

black:
	black --exclude --check --diff --line-length=88 slac tests

flake8:
	flake8 --config .flake8 slac tests

code-quality: reformat mypy black flake8

bump-version:
	poetry version

deploy: .check-env-vars .deps build bump-version
	poetry config repo.pypi-switch https://pypi.switch-ev.com/
	poetry config http-basic.pypi-switch ${PYPI_USER} ${PYPI_PASS}
	poetry publish -r pypi-switch

deploy-twine: .check-env-vars .deps build
	python -m twine upload -u $(PYPI_USER) -p $(PYPI_PASS) --repository-url https://pypi.switch-ev.com dist/*
