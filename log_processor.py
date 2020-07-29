#!/bin/python3

import re
import sys
import os

class ParsedData:

    def __init__(self):
        print("init")

        self.spectators= set()
        self.players= set()
        self.admin= set()
        self.map="UNKNOWN"
        self.inRaceCheck= set()

    def _addSpectator(self, name):
        self.players.discard(name)
        self.inRaceCheck.discard(name)

        self.spectators.add(name)

    def _entersGame(self, name):
        self.spectators.discard(name)

        self.players.add(name)

    def _renaming(self, oldName, newName):
        if oldName != newName:
            if oldName in self.players :
                self.players.discard(oldName)
                self.players.add(newName)

            if newName in self.players :
                self.spectators.discard(oldName)
                self.spectators.discard(newName)
            elif oldName in self.spectators :
                self.spectators.discard(oldName)
                self.spectators.add(newName)

            if oldName in self.admin :
                self.admin.discard(oldName)
                self.admin.add(newName)

            if oldName in self.inRaceCheck :
                self.inRaceCheck.discard(oldName)
                self.inRaceCheck;add(newName)

    def _left(self, name):
        self.spectators.discard(name)
        self.players.discard(name)
        self.admin.discard(name)
        self.inRaceCheck.discard(name)

    def _checkRacers(self):
        tmp= self.players & self.inRaceCheck
        b= (tmp <= self.players)
        
        self.players= tmp

        return b

    def _talked(self, name):
        if not (name in self.spectators) and (not name in self.players) :
            self._addSpectator(name)
            return True
        
        return False

    def __admin(self, name):
        self.admin.add(name)
    

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
        elif line.endswith('has finished the race.\n'):
            res= re.findall('^(.*) has finished the race.*$', line)
            if res :
                self.inRaceCheck.add(res[0])
                if not (res[0] in self.players) :
                    self._entersGame(res[0])
                    return True
        elif line.endswith('ran out of time.\n'):
            res= re.findall('^(.*) ran out of time.*$', line)
            if res :
                self.inRaceCheck.add(res[0])
                if not (res[0] in self.players) :
                    self._entersGame(res[0])
                    return True
        elif line.startswith("The round has ended."):
                return len(self.players)>1 and self._checkRacers()
        elif line.startswith("Speeding off to level..."):
            self.inRaceCheck.clear()
            return False
        elif line.endswith(' passed authentication.'):
            res= re.findall('^\*(.*) passed authentication.*$', line)
            if res :
                self._admin(res[0])
                return True
        elif line.startswith('<'):
            res= re.findall('^<(.*)> .*$', line)
            if res :
                return self._talked(res[0])

        
        return False

    def strData(self):
        res= self.map+'\n'

        res+= str(len(self.spectators))
        for spect in self.spectators:
            if spect in self.admin:
                res+= '\n__'+spect+'__'
            else:
                res+= '\n'+spect

        res+= '\n' + str(len(self.players))
        for player in self.players:
            if player in self.admin:
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



