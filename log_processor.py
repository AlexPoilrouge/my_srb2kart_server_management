#!/bin/python3

import re
import sys
import os

class ParsedData:

    def __init__(self):
        print("init")

        self.spectators= []
        self.players= []
        self.admin= []
        self.map="UNKNOWN"

    def _addSpectator(self, name):
        if self.players.count(name):
            self.players.remove(name)

        if not self.spectators.count(name):
            self.spectators.append(name)

    def _entersGame(self, name):
        if self.spectators.count(name):
            self.spectators.remove(name)

        if not self.players.count(name):
            self.players.append(name)

    def _renaming(self, oldName, newName):
        if self.spectators.count(oldName):
            i= self.spectators.index(oldName)
            self.spectators[i]= newName
        elif self.players.count(name):
            i= self.players.index(oldName)
            self.players[i]= newName

    def _left(self, name):
        if self.spectators.count(name):
            self.spectators.remove(name)
        elif self.players.count(name):
            self.players.remove(name)
        if self.admin.count(name):
            self.admin.remove(name)

    def __admin(self, name):
        if not self.admin.count(name):
            self.admin.append(name)
    

    def processLine(self, line):
        if line.startswith('*'):
            res= re.findall('^\*(.*) became a spectator.*$', line)
            if res:
                self._addSpectator(res[0])
                return True

            res= re.findall('^\*(.*) has joined the game.*$', line)
            if res:
                if len(self.players)>0:
                    self._addSpectator(res[0])
                else :
                    self._entersGame(res[0])
                return True

            res= re.findall('^\*(.*) entered the game.*$', line)
            if res:
                self._entersGame(res[0])
                return True

            res= re.findall('^\*(.*) left the game.*$', line)
            if res:
                self._left(res[0])
                return True

            res= re.findall('^\*(.*) renamed to (.*)$', line)
            if res and len(res[0])==2:
                self._renaming(res[0][0], res[0][1])
                return True
        elif line.startswith('Map is now'):
            self.map= line[12:-2]
            return True
        elif line.endswith('has finished the race.'):
            res= re.findall('^\*(.*) has finished the race.*$', line)
            if res and not self.players.count(res[0]) :
                self._entersGame(res[0])
                return True
        elif line.endswith('ran out of time.'):
            res= re.findall('^\*(.*) ran out of time.*$', line)
            if res and not self.players.count(res[0]) :
                self._entersGame(res[0])
                return True
        elif line.endswith(' passed authentication.'):
            res= re.findall('^\*(.*) passed authentication.*$', line)
            if res :
                self._admin(res[0])
                return True

        
        return False

    def strData(self):
        res= self.map+'\n'

        res+= str(len(self.spectators))
        for spect in self.spectators:
            if self.admin.count(spect):
                res+= '\n__'+spect+'__'
            else:
                res+= '\n'+spect

        res+= '\n' + str(len(self.players))
        for player in self.players:
            if self.admin.count(player):
                res+= '\n__'+player+'__'
            else:
                res+= '\n'+player

        return res

if __name__ == "__main__":
    data= ParsedData()
    while True:
        line= sys.stdin.readline()

        if len(line) == 0:
            break
        elif data.processLine(line) :

            if len(sys.argv) <= 1 :
                print(data.strData())
            else:
                filename= os.path.basename(sys.argv[1])
                filepath= os.path.abspath(os.path.dirname(sys.argv[0]))+'/'+filename
                f = open(filepath, "w")
                f.write(data.strData())
                f.close()



