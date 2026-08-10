from app.plugins import PluginBase, Menu, MountPoint
from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.utils.translation import gettext as _

import json, shutil
import ctypes
import sys

def get_memory_stats():
    """
    Get node total memory and memory usage.
    """
    try:
        if sys.platform == 'win32':
            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ('dwLength', ctypes.c_ulong),
                    ('dwMemoryLoad', ctypes.c_ulong),
                    ('ullTotalPhys', ctypes.c_ulonglong),
                    ('ullAvailPhys', ctypes.c_ulonglong),
                    ('ullTotalPageFile', ctypes.c_ulonglong),
                    ('ullAvailPageFile', ctypes.c_ulonglong),
                    ('ullTotalVirtual', ctypes.c_ulonglong),
                    ('ullAvailVirtual', ctypes.c_ulonglong),
                    ('ullAvailExtendedVirtual', ctypes.c_ulonglong),
                ]

            mem_status = MEMORYSTATUSEX()
            mem_status.dwLength = ctypes.sizeof(MEMORYSTATUSEX)

            if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem_status)):
                return {}

            total = int(mem_status.ullTotalPhys)
            free = int(mem_status.ullAvailPhys)

            return {
                'total': total,
                'free': free,
                'used': total - free,
            }

        with open('/proc/meminfo', 'r') as mem:
            ret = {}
            tmp = 0
            for i in mem:
                sline = i.split()
                if str(sline[0]) == 'MemTotal:':
                    ret['total'] = int(sline[1])
                elif str(sline[0]) in ('MemFree:', 'Buffers:', 'Cached:'):
                    tmp += int(sline[1])
            ret['free'] = tmp
            ret['used'] = int(ret['total']) - int(ret['free'])

            ret['total'] *= 1024
            ret['free'] *= 1024
            ret['used'] *= 1024
        return ret
    except:
        return {}


class Plugin(PluginBase):
    def main_menu(self):
        return [Menu(_("Diagnostic"), self.public_url(""), "fa fa-chart-pie fa-fw")]

    def app_mount_points(self):
        @login_required
        def diagnostic(request):
            # Disk space
            total_disk_space, used_disk_space, free_disk_space = shutil.disk_usage('./')

            template_args = {
                'title': 'Diagnostic',
                'total_disk_space': total_disk_space,
                'used_disk_space': used_disk_space,
                'free_disk_space': free_disk_space
            }

            # Memory
            memory_stats = get_memory_stats()
            if 'free' in memory_stats:
                template_args['free_memory'] = memory_stats['free']
                template_args['used_memory'] = memory_stats['used']
                template_args['total_memory'] = memory_stats['total']

            return render(request, self.template_path("diagnostic.html"), template_args)

        return [
            MountPoint('$', diagnostic)
        ]


