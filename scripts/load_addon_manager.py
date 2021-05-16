#!/bin/bash/python3

import os
from os import path

import re

import pathlib

import sys


class AddonLoadManager:
    ADDON_EXTENSION_LIST= ["pk7", "kart", "lua", "wad", "pk3"]

    def __init__(self, dirList='.'):
        self.files= []

        for dir in dirList:
            if path.isdir(dir):
                self.process(dir)

    def process(self, dir):
        for file in os.listdir(dir):
            b= False
            for ext in AddonLoadManager.ADDON_EXTENSION_LIST:
                if file.endswith('.'+ext):
                    b= True
                    break
            
            filepath=dir+'/'+file
            if b and os.path.isfile(filepath):
                self.files.append(filepath)

    def _check_line(self, line):
        res= re.search(r"^\s*((\'(.*)\')|(\"(.*)\"))\s*\<\s*((\'(.*)\')|(\"(.*)\"))\s*$", line)
        if (res and res.group(3) and res.group(8)):
            return ('A_BEFORE_B', res.group(3), res.group(8))

        res= re.search(r"^\s*FIRST\s*\: [\"\'](.*)[\"\']", line)
        if(res and res.group(1)):
            return ('FIRST', res.group(1))

        res= re.search(r"^\s*LAST\s*\: [\"\'](.*)[\"\']", line)
        if(res and res.group(1)):
            return ('LAST', res.group(1))

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
                    f_b= t_checked_line[2]
                    i_f_a= self.files.index(f_a) if (f_a in self.files) else -1
                    i_f_b= self.files.index(f_b) if (f_b in self.files) else -1

                    if (i_f_b<0) or (i_f_a<0) or (i_f_a<i_f_b):
                        continue

                    self.files.remove(f_a)
                    self.files.insert(i_f_b,f_a)
                elif t_checked_line[0]=='FIRST':
                    f= t_checked_line[1]

                    self.files.remove(f)
                    self.files.insert(0,f)
                elif t_checked_line[0]=='LAST':
                    f= t_checked_line[1]

                    self.files.remove(f)
                    self.files.insert(len(f),f)


    def generateLoadFile(self, filename="dl_load.cfg"):
        filepath=str(pathlib.Path(__file__).parent.absolute())+'/'+filename

        with open(filepath, 'w') as file:
            for addon in self.files:
                file.write("wait\naddfile \""+str(addon)+"\"\n")
            file.write("wait\n")


if __name__ == "__main__":
    if len(sys.argv)<2 :
        print("Error - Need dir")
        exit(1)

    alm= AddonLoadManager(sys.argv[1:])
    alm.ordering()
    alm.generateLoadFile()

