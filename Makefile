# Makefile for orbital_processor project
# Windows / cmd.exe compatible

PROJECT_NAME = orbital_processor
PYTHON = python
PIP = $(PYTHON) -m pip
VENV = bpd
REQUIREMENTS = requirements.txt

# Default target
.PHONY: all
all: ensure-python install-deps compile

# 0. Ensure Python is installed via winget (Windows only)
.PHONY: ensure-python
ensure-python:
	@echo === Checking for Python installation via winget ===
	@winget --version >NUL 2>&1 || (echo Error: winget is not available. This Makefile requires winget on Windows. & exit 1)
	@python --version >NUL 2>&1 || ( \
		echo Python not found. Installing latest Python via winget... & \
		winget install --id Python.Python.3 --source winget --silent --accept-source-agreements --accept-package-agreements \
		|| (echo Failed to install Python. Please install it manually. & exit 1) \
	)
	@echo Python is installed or already present.

# 1. Pull/check code (ensure file exists)
.PHONY: pull
pull: ensure-python
	@echo Pulling from repo...
	@git pull || (echo Warning: git pull failed. Continuing with existing code...)
	@if not exist orbit.py ( \
		echo Error: orbit.py not found! & \
		exit 1 \
	)

# 2. Recreate virtual environment and install dependencies
.PHONY: install-deps
install-deps: pull $(VENV)

# Force venv recreation every time by making the target phony
.PHONY: $(VENV)
$(VENV): $(REQUIREMENTS)
	@echo === Recreating virtual environment and installing dependencies ===
	@if exist "$(VENV)" ( \
		echo Removing existing virtual environment "$(VENV)"... & \
		rmdir /S /Q "$(VENV)" \
	)
	@echo Creating new virtual environment "$(VENV)"...
	@$(PYTHON) -m venv "$(VENV)"
	@call "$(VENV)\Scripts\activate.bat" && \
		$(PIP) install --upgrade pip && \
		$(PIP) install -r "$(REQUIREMENTS)"

# 3. Compile to bytecode (.pyc)
.PHONY: compile
compile: install-deps pull
	@echo === Compiling to bytecode ===
	@call "$(VENV)\Scripts\activate.bat" && \
		$(PYTHON) -m compileall -b -f orbit.py
	@echo Bytecode generated in __pycache__\

# 4. Help target
.PHONY: help
help:
	@echo Available targets:
	@echo   make all           - ensure Python + recreate venv + install deps + compile
	@echo   make ensure-python - check/install Python via winget (Windows)
	@echo   make pull          - pull latest code and check for orbit.py
	@echo   make install-deps  - recreate venv and install dependencies
	@echo   make compile       - compile to .pyc (runs pull first)
	@echo   make help          - show this help
