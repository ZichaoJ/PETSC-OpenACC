#! /usr/bin/env python3
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2017 Pi-Yueh Chuang <pychuang@gwu.edu>
#
# Distributed under terms of the MIT license.

"""
generate plots from strong scaling results in folder "runs"
"""

import glob
import re
from matplotlib import pyplot


def get_file_list(prefix, run_type):
    """get file lists of log files belonging to each executables

    Assume log files have this pattern:
        <prefix>/<run_type>/<run_type>-<executable name>-XXXXXXXXXXX.log

    Args:
        prefix [in]: prefix of the folder holding log files
        run_type [in]: the type of run, i.e., the PBS scipt used

    Return:
        If log files exist, a dictionary. The key in the dictionary is names of
        executable, while the values are lists of log files belonging to each
        executable.

        If log files don't exist or the path is wrong, return None.
    """

    tmpFileList = glob.glob("{0}/{1}/*.log".format(prefix, run_type))

    if len(tmpFileList) == 0:
        return None

    file_list = {}

    for file in tmpFileList:
        match = re.match(
            r"{0}/{1}/{1}-(?P<exe>\S*?)-[0-9-:]*?.log".format(prefix, run_type),
            file)

        if match is None:
            raise IOError("The log file {0} ".format(tmpFileList[0]) +
                          "does not fit filename pattern.")

        exe = match.groupdict()['exe']

        if exe not in file_list:
            file_list[exe] = []

        file_list[exe].append(file)

    return file_list


def get_time_KSPSolve(file_lists):
    """get averaged inclusive wall time of KSPSolve

    Args:
        file_lists [in]: the out put of the function get_file_list

    Return:
        averaged inclusive wall time for each executable and different number
        of CPU cores, in dict format
    """

    count = dict.fromkeys(sorted(file_lists.keys()), 0)
    times = dict.fromkeys(sorted(file_lists.keys()), None)

    for exe, files in file_lists.items():
        times[exe] = {}
        for file in files:
            count[exe] += 1
            with open(file, 'r') as f:
                content = f.read()

            matches = re.finditer(
                "([0-9]*?) Cores[\s\S\n]*?Time.*?: " +
                "\[(\S*?), (\S*?), (\S*?)\]",
                content)

            for match in matches:
                Np, init, prep, solve = match.groups()
                Np = int(Np)
                if Np not in times[exe]:
                    times[exe][Np] = 0.0
                times[exe][Np] += float(solve)

        times[exe].update((k, v/count[exe]) for k, v in times[exe].items())

    return times


def create_scaling_plots(case, times, base_key):
    """create plots

    Args:
        case [in]: the type of run, i.e., the PBS scipt used
        times [in]: the out put of the function get_time_KSPSolve
        base_key [in]: the first item we want to show in legend
    """

    pyplot.figure()

    pyplot.loglog(list(times[base_key].keys()),
                  list(times[base_key].values()), lw=2.5, label=base_key)

    for exe, time in times.items():
        if exe == base_key:
            continue
        pyplot.loglog(list(time.keys()), list(time.values()), lw=2.5, label=exe)

    pyplot.title("Strong scaling: {0}".format(case))
    pyplot.xlabel("Number of CPU cores")
    pyplot.ylabel("Inclusive wall time of KSPSolve")
    pyplot.legend(loc=0)
    pyplot.grid()
    pyplot.savefig("strong_scaling_{0}.png".format(case))


def create_speedup_plots(case, times, base_key):
    """
    """

    n_groups = len(times[base_key])
    n_bars_per_group = len(times)
    speedup = times.copy()

    for exe in times.keys():
        for Np in times[exe].keys():
            speedup[exe][Np] = times[base_key][Np] / times[exe][Np]

    pyplot.figure()

    pyplot.bar([(n_bars_per_group+2)*n for n in range(n_groups)],
               [v for (k, v) in sorted(speedup[base_key].items())], label=exe)

    i = 1
    for exe, s in speedup.items():

        if exe == base_key:
            continue

        pyplot.bar([(n_bars_per_group+2)*n+i for n in range(n_groups)],
                   [v for (k, v) in sorted(s.items())], label=exe)
        i += 1

    pyplot.title("Speed of KSPSolve from {0}".format(case))
    pyplot.xticks(
        [(n_bars_per_group+2)*n+n_bars_per_group/2 for n in range(n_groups)],
        [k for (k, v) in sorted(speedup[base_key].items())], label=exe)
    pyplot.xlabel("Number of CPU cores")
    pyplot.ylabel("Speedup of KSPSolve")
    pyplot.legend(loc=0)
    pyplot.grid(which='both', axis='y')
    pyplot.savefig("speed_up_{0}.png".format(case))


# main function
if __name__ == "__main__":

    # get the path of "runs" folder through the path to this Python script
    prefix = glob.os.path.normpath(
        glob.os.path.join(glob.os.path.dirname(__file__), "../runs"))

    # read data and plot
    for case in ["single-node-scaling", "multiple-node-scaling"]:

        # get file lists, catagorized by names of executables
        file_lists = get_file_list(prefix, case)

        # get averaged wall time
        times = get_time_KSPSolve(file_lists)

        # plot strong scaling
        create_scaling_plots(case, times, "original")

        create_speedup_plots(case, times, "original")
