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

                    r_f_a= f_a
                    for file in self.files:
                        if file.endswith('/'+f_a):
                            r_f_a= file
                            break
                    r_f_b= f_b
                    for file in self.files:
                        if file.endswith('/'+f_b):
                            r_f_b= file
                            break

                    i_f_a= self.files.index(r_f_a) if (r_f_a in self.files) else -1
                    i_f_b= self.files.index(r_f_b) if (r_f_b in self.files) else -1

                    if (i_f_b<0) or (i_f_a<0) or (i_f_a<i_f_b):
                        continue

                    self.files.remove(dir+'/'+f_a)
                    self.files.insert(i_f_b,f_a)
                elif t_checked_line[0]=='FIRST':
                    f= t_checked_line[1]

                    r_f= f
                    for file in self.files:
                        if file.endswith('/'+f):
                            r_f= file
                            break

                    if r_f in self.files:
                        self.files.remove(r_f)
                        self.files.insert(0,r_f)
                elif t_checked_line[0]=='LAST':
                    f= t_checked_line[1]

                    r_f= f
                    for file in self.files:
                        if file.endswith('/'+f):
                            r_f= file
                            break

                    if r_f in self.files:
                        self.files.remove(r_f)
                        self.files.insert(len(self.files),r_f)


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

