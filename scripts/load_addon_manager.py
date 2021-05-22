#!/bin/bash/python3

import os
from os import path

import re

import pathlib

import sys


class AddonLoadManager:
    ADDON_EXTENSION_LIST= ["pk7", "kart", "lua", "wad", "pk3"]

    def __init__(self, dirList='.'):
        self.dirs= []
        self.files= []

        for dir in dirList:
            if path.isdir(dir):
                self.process(dir)

    def process(self, dir):
        count= 0
        for file in os.listdir(dir):
            b= False
            for ext in AddonLoadManager.ADDON_EXTENSION_LIST:
                if file.endswith('.'+ext):
                    b= True
                    break
            
            filepath=dir+'/'+file
            if b and os.path.isfile(filepath):
                count+= 1
                self.files.append(filepath)
        
        if count>0:
            self.dirs.append(dir)


    def _check_line(self, line):
        res= re.search(r"^\s*(r?)((\'(.*)\')|(\"(.*)\"))\s*\<\s*(r?)((\'(.*)\')|(\"(.*)\"))\s*$", line)
        r1= res.group(4) if (res and res.group(4)) else (res.group(6) if (res and res.group(6)) else None)
        r2= res.group(10) if (res and res.group(10)) else (res.group(12) if (res and res.group(12)) else None)
        if (r1 and r2):
            return ('A_BEFORE_B', r1, (res.group(1)=='r'), r2, (res.group(7)=='r'))

        res= re.search(r"^\s*FIRST\s*\: (r?)[\"\'](.*)[\"\']", line)
        if(res and res.group(2)):
            return ('FIRST', res.group(2), (res.group(1)=='r'))

        res= re.search(r"^\s*LAST\s*\: (r?)[\"\'](.*)[\"\']", line)
        if(res and res.group(2)):
            return ('LAST', res.group(2), (res.group(1)=='r'))

        return ("UNKNOWN")

    def ordering(self, orderFile="./addon_load_order.txt"):
        if not os.path.isfile(orderFile):
            with open(orderFile, 'a'): pass
            return

        with open(orderFile, 'r') as file:
            for line in file:
                t_checked_line= self._check_line(line)

                if t_checked_line=="UNKNOWN":
                    continue
                elif t_checked_line[0]=='A_BEFORE_B':
                    f_a= t_checked_line[1]
                    try:
                        regex_a= (re.compile(f_a) if t_checked_line[2] else None)
                    except:
                        regex_a= None
                    f_b= t_checked_line[3]
                    try:
                        regex_b= (re.compile(f_b) if t_checked_line[4] else None)
                    except:
                        regex_b= None

                    r_f_a= f_a
                    for file in self.files:
                        basename=  os.path.basename(file)
                        if (regex_a and re.match(regex_a,basename)) or basename==f_a:
                                r_f_a= file
                                break

                    r_f_b= f_b
                    for file in self.files:
                        basename=  os.path.basename(file)
                        if (regex_b and re.match(regex_b,basename)) or basename==f_b:
                                r_f_b= file
                                break

                    i_f_a= self.files.index(r_f_a) if (r_f_a in self.files) else -1
                    i_f_b= self.files.index(r_f_b) if (r_f_b in self.files) else -1

                    if (i_f_b<0) or (i_f_a<0) or (i_f_a<i_f_b):
                        continue

                    self.files.remove(r_f_a)
                    self.files.insert(i_f_b,r_f_a)
                elif t_checked_line[0]=='FIRST':
                    f= t_checked_line[1]
                    try:
                        regex= (re.compile(f) if t_checked_line[2] else None)
                    except:
                        regex= None

                    r_f= f
                    for file in self.files:
                        basename=  os.path.basename(file)
                        if (regex and re.match(regex,basename)) or basename==f:
                            r_f= file
                            break

                    if r_f in self.files:
                        self.files.remove(r_f)
                        self.files.insert(0,r_f)
                elif t_checked_line[0]=='LAST':
                    f= t_checked_line[1]
                    try:
                        regex= (re.compile(f) if t_checked_line[2] else None)
                    except:
                        regex= None

                    r_f= f
                    for file in self.files:
                        basename=  os.path.basename(file)
                        if (regex and re.match(regex,basename)) or basename==f:
                            r_f= file
                            break

                    if r_f in self.files:
                        self.files.remove(r_f)
                        self.files.insert(len(self.files),r_f)


    def generateLoadFile(self, filename="dl_load.cfg"):
        filepath=str(pathlib.Path(__file__).parent.absolute())+'/'+filename

        with open(filepath, 'w') as file:
            for addon in self.files:
                file.write("wait 10\naddfile \""+str(addon)+"\"\n")
            file.write("wait\n")


if __name__ == "__main__":
    if len(sys.argv)<2 :
        print("Error - Need dir")
        exit(1)

    alm= AddonLoadManager(sys.argv[1:])
    alm.ordering()
    alm.generateLoadFile()

