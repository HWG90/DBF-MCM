"""Reject Windows Store Python before any build/deployment filesystem work."""
import sys

def blocked_path(path):
    value=str(path).replace('\\','/').lower()
    return any(part in value for part in ['/windowsapps/', '/localcache/', 'pythonsoftwarefoundation.python'])

def require_physical_runtime(executable=None):
    if blocked_path(executable or sys.executable):
        raise RuntimeError('Microsoft Store/WindowsApps Python is unsupported: AppData may be virtualized. Use build.ps1 with a non-Store Python interpreter; deploy.ps1 verifies the physical installed file.')
