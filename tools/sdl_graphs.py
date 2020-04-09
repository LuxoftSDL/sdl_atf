#!/usr/bin/env python
# coding: utf-8

import matplotlib
matplotlib.use('Agg')
from scipy.stats import norm
from matplotlib import pyplot as plt
import matplotlib.dates as mdates
import numpy as np
from datetime import datetime
import datetime as dt
import argparse
import os
import re


def generator(line):
    line = line.split()
    for x in line:
        yield x

def sdl_start_time_ps(lines):
    process_start = datetime.strptime(lines[0].split()[1], "%H:%M:%S")
    return process_start

def parse_ps(line):
    # time + ps --no-headers --format "start %cpu cp cputime %mem sz thcount"
    line = line.split()
    record = {}
    record["time"] = datetime.strptime(line[0][:-3], "%H:%M:%S:%f")
    record["start"] = datetime.strptime(line[1], "%H:%M:%S")
    record["%cpu"] = float(line[2])
    record["cp"] = float(line[3])
    record["cputime"] = datetime.strptime(line[4], "%H:%M:%S")
    record["%mem"] = float(line[5])
    record["sz"] = float(line[6])
    record["thcount"] = int(line[7])
    return record

def sdl_start_time_docker(lines):
    line = lines[0].split()
    
    process_start = datetime.strptime(line[0][:-3], "%H:%M:%S:%f")
    return process_start
    
def parse_docker(line):
    # docker stats --format "{{.Name}} {{.CPUPerc}} {{.MemUsage}}  {{.PIDs}}"  --no-stream 
    columns = generator(line)
    
    next_col  = lambda : next(columns)
    record = {}
    record["time"] = datetime.strptime(next_col()[:-3], "%H:%M:%S:%f")
    record["Name"] = next_col()
    record["CPUPerc"] = float(next_col().replace("%", ""))
    record["MemUsage"] = float(re.sub(r'[A-z]', '', next_col()))
    slash = next_col()
    record["MemLimit"] = next_col()
    record["PIDs"] = int(next_col())
    
    return record

def graphs(record_type):
    if record_type == "ps":
        return ["%cpu", "%mem", "sz", "thcount"]
    if record_type == "pidstat":
        return ["%CPU", "VSZ", "RSS", "%MEM", "threads"]
    if record_type == "docker":
        return ["CPUPerc", "MemUsage", "PIDs"]
    raise "Unknown record_type {}".format(record_type)

def sdl_start_time_pidstat(lines):
    process_start = datetime.strptime(lines[0].split()[0], "%H:%M:%S")
    return process_start

def parse_pidstat(line):
    # pidstat -urdlv -h
    columns = generator(line)
    next_col  = lambda : next(columns)
    record = {}
    record["time"] = datetime.strptime(next_col(), "%H:%M:%S")
    uid = next_col()
    pid = next_col()
    record["%usr"] = float(next_col())
    record["%system"] = float(next_col())
    record["%guest"] = float(next_col())
    record["%wait"] = float(next_col())
    record["%CPU"] = float(next_col())
    record["CPU"] = int(next_col())
    record["minflt/s"] = float(next_col())
    record["majflt/s"] = float(next_col())
    record["VSZ"] = int(next_col())
    record["RSS"] = int(next_col())
    record["%MEM"] = float(next_col())
    record["kB_rd/s"] = float(next_col())
    record["kB_wr/s"] = float(next_col())
    record["kB_ccwr/s"] = float(next_col())
    record["iodelay"] = float(next_col())
    record["threads"] = float(next_col())
    record["fd-nr"] = float(next_col())
    record["Command"] = next_col()
    return record

def read_records(filename, parsing_func, parsing_proc_stat):
    f=open(filename)
    lines = f.readlines()
    process_start = parsing_proc_stat(lines)
    print("Started at ", process_start)
    records = []
    for line in lines:
        try:
            record = parsing_func(line)
            delta = record["time"] - process_start
            delta = datetime(1970,1,1) + delta
            record["delta"] = delta
            records.append(record)
        except Exception as e:
            print(line)
            raise e
    return records

def plot(x, y ,records, title, xlable, ylable, file_pattern):
    assert(len(x) == len(y))
    assert(len(x) != 0)
    fig, ax = plt.subplots(figsize=(20,5))
    ax.plot(x,y)
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%M:%S'))
    fig.autofmt_xdate()
    plt.title(title)
    plt.ylabel(ylable)
    plt.xlabel(xlable)
    plt.savefig("{}_{}.png".format(file_pattern, ylable), format='png')
    # plt.show()
    
def plot_record(key, records, title = None, xlable="Time", ylable=None, file_pattern = "output"):
    if ylable is None:
        ylable = key
    if title is None:
        title = key    
    x = [record["delta"] for record in records]
    y = [record[key] for record in records]
    plot(x, y, records, title, xlable, ylable, file_pattern)

def process_records(records, record_type, title, output_dir):
    if len(records) == 0:
        print("empty records :".format(record_type))
    for key in graphs(record_type):
        plot_record(key, records, title = title, 
        file_pattern = output_dir + "_" + record_type)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pidstat_file", help='''File with pidstat output in format : 
        pidstat -urdlv -h ''',
                        type=str)
    parser.add_argument("--ps_file", help='''File with ps output in format : 
        time + ps --no-headers --format "start %cpu cp cputime %mem sz thcount"''',
                        type=str)
    parser.add_argument("--docker_file", help='''File with docker stats output in format : 
            docker stats --format "{{.Name}} {{.CPUPerc}} {{.MemUsage}}  {{.PIDs}}"''',
                        type=str)
    parser.add_argument("--output_dir", help='''Output Directory''',
                        type=str)
    parser.add_argument("--title", help='''Graph title''',
                        type=str)
    args = parser.parse_args()

    if args.pidstat_file:
        print("pidstat log file : {}".format(args.pidstat_file))
        records = read_records(args.pidstat_file, parse_pidstat, sdl_start_time_pidstat)
        process_records(records, "pidstat", 
            args.title + "\npidstat -urdlv -h", 
            os.path.join(args.output_dir , "pidstat"))

    if args.ps_file:
        print("ps log file : {}".format(args.ps_file))
        records = read_records(args.ps_file, parse_ps, sdl_start_time_ps)
        process_records(records, "ps",
            args.title + '\nps --no-headers --format "start %cpu cp cputime %mem sz thcount"',
            os.path.join(args.output_dir , "ps"))
    if args.docker_file:
        print("docker log file : {}".format(args.docker_file))
        records = read_records(args.docker_file, parse_docker, sdl_start_time_docker)
        process_records(records, "docker",
            args.title + '\n{{.Name}} {{.CPUPerc}} {{.MemUsage}}  {{.PIDs}}',
            os.path.join(args.output_dir , "docker"))

    
    print("Done")

if __name__ == "__main__":
    main()
