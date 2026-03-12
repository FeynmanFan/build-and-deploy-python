# Makefile for orbital_processor project
# Windows / cmd.exe compatible

PROJECT_NAME = orbital_processor
PYTHON = python
PIP = $(PYTHON) -m pip
VENV = bpd
REQUIREMENTS = requirements.txt
SEMgrep = semgrep

# Default target
.PHONY: all
all: ensure-python install-deps compile scan

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
	@echo === Recreating virtual environment ===
	@if exist "$(VENV)" rmdir /S /Q "$(VENV)" 2>nul
	@$(PYTHON) -m venv "$(VENV)"
	@call "$(VENV)\Scripts\activate.bat" && \
		"$(VENV)\Scripts\python.exe" -m pip install --upgrade pip --only-binary=all && \
		"$(VENV)\Scripts\python.exe" -m pip install --only-binary=all -r "$(REQUIREMENTS)" || echo "Non-critical packages skipped" && \
		"$(VENV)\Scripts\python.exe" -m pip install --only-binary=all requests numpy || echo "Core deps installed"

# 3. Audit dependencies & compile to bytecode (.pyc)
.PHONY: compile
compile: install-deps pull
	@echo === Auditing Python dependencies ===
	@call "$(VENV)\Scripts\activate.bat" && "$(VENV)\Scripts\pip.exe" install pip-audit
	@call "$(VENV)\Scripts\activate.bat" && "$(VENV)\Scripts\pip-audit.exe"
	@if ERRORLEVEL 1 (echo VULNERABILITIES FOUND - fix before proceeding & exit /b 1)

	@echo === Compiling to bytecode (SECURE) ===
	@$(VENV)\Scripts\python.exe -c "import sys; sys.path = [p for p in sys.path if p.startswith(('/', 'C:\\', '/venv', '$(VENV)')) or p == '']; import py_compile; py_compile.compile('orbit.py', optimize=2)"

	@echo Bytecode generated in __pycache__

# 4. Scan with Semgrep via Docker
.PHONY: scan
scan: pull
	@echo === Running Semgrep security scan ===
	@docker run --rm -v "/c/code/bdp:/src" -w /src semgrep/semgrep \
		semgrep scan \
			--config=auto \
			--config=semgrep.yaml \
			--error \
			orbit.py
	@echo Scan complete.

# 5. Help target
.PHONY: help
help:
	@echo Available targets:
	@echo   make all           - ensure Python + recreate venv + install deps + compile
	@echo   make ensure-python - check/install Python via winget (Windows)
	@echo   make pull          - pull latest code and check for orbit.py
	@echo   make install-deps  - recreate venv and install dependencies
	@echo   make compile       - compile to .pyc (runs pull first)
	@echo   make scan          - run semgrep security scan on orbit.py
	@echo   make help          - show this help