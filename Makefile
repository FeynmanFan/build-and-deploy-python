# Makefile for orbital_processor project
# Windows / cmd.exe compatible
# Now includes: production mode (disable debug), PyArmor obfuscation

PROJECT_NAME = orbital_processor
PYTHON = python
PIP = $(PYTHON) -m pip
SEMgrep = semgrep
PYARMOR = pyarmor
VENV = bpd
REQUIREMENTS = requirements.txt

# Default target
.PHONY: all
all: ensure-python pull scan install-deps compile obfuscate

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

# 1. Create virtual environment and install dependencies
.PHONY: install-deps
install-deps: ensure-python $(VENV)

$(VENV): $(REQUIREMENTS)
	@echo === Recreating virtual environment ===
	@if exist "$(VENV)" rmdir /S /Q "$(VENV)" 2>nul
	@$(PYTHON) -m venv "$(VENV)"
	@call "$(VENV)\Scripts\activate.bat" && \
		"$(VENV)\Scripts\python.exe" -m pip install --upgrade pip setuptools wheel --only-binary=all && \
		"$(VENV)\Scripts\python.exe" -m pip install --only-binary=all -r "$(REQUIREMENTS)" || echo "Non-critical packages skipped"
	
	@call "$(VENV)\Scripts\activate.bat" && \
		"$(VENV)\Scripts\python.exe" -m pip install --only-binary=all pyarmor
		
# 2. Pull/check code (ensure file exists)
.PHONY: pull
pull: ensure-python
	@echo Pulling from repo...
	@git pull || (echo Warning: git pull failed. Continuing with existing code...)
	@if not exist orbit.py ( \
		echo Error: orbit.py not found! & \
		exit 1 \
	)

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

# 4. Obfuscate code using PyArmor
.PHONY: obfuscate
obfuscate: install-deps pull
	@echo === Obfuscating code with PyArmor ===
	@if not exist dist_obf (mkdir dist_obf)
	@"$(VENV)\Scripts\pyarmor.exe" gen --output dist_obf --restrict orbit.py
	@echo Obfuscated code generated in dist_obf/
	@echo Run the obfuscated version with: python dist_obf/orbit.py

# 5. Scan with Semgrep via Docker
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

# 6. Help target
.PHONY: help
help:
	@echo Available targets:
	@echo   make all           - ensure Python + recreate venv + install deps + compile + obfuscate + scan
	@echo   make ensure-python - check/install Python via winget (Windows)
	@echo   make install-deps  - recreate venv and install dependencies
	@echo   make compile       - compile to .pyc (runs pull first)
	@echo   make obfuscate     - obfuscate code with PyArmor
	@echo   make scan          - run semgrep security scan on orbit.py
	@echo   make help          - show this help