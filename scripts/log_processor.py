#!/bin/python3

import re
import sys
import os

class ParsedData:

    def __init__(self):

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
                self.inRaceCheck.add(newName)

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
        n= name if not ( name.startswith('@') and name[1:] in self.admin ) else name[1:]
        if not (n in self.spectators) and (not n in self.players) :
            self._addSpectator(n)
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
                if res[0] in self.spectators or not (res[0] in self.players) :
                    self._entersGame(res[0])
                    return True
        elif line.endswith('ran out of time.\n'):
            res= re.findall('^(.*) ran out of time.*$', line)
            if res :
                self.inRaceCheck.add(res[0])
                if res[0] in self.spectators or not (res[0] in self.players) :
                    self._entersGame(res[0])
                    return True
        elif line.startswith("The round has ended."):
                return len(self.players)>1 and self._checkRacers()
        elif line.startswith("Speeding off to level..."):
            self.inRaceCheck.clear()
            return False
        elif line.endswith(' passed authentication.\n'):
            res= re.findall('^(.*) passed authentication.*$', line)
            if res :
                self.admin.add(res[0])
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

class StrashbotLogParser:
    MODE= {
        'NONE': 0b0,
        'SPBATK': 0b1,
        'ELIM': 0b10,
        'FRIEND': 0b100,
        'JUICEBOX': 0b1000,
        'ACRO': 0b10000,
        'HP': 0b100000,
        'CRUEL': 0b1000000
    }

    def __init__(self, dataFile=None, mapFile=None, skinFile=None, id='strash'):
        print("[SbLP] init")

        self.id= id
        self.mode= self.MODE['NONE']
        self.mode_manual= self.MODE['NONE']
        self.ft=0

        self.dataFile= dataFile
        self.maps= {}
        self.mapDataFile= mapFile
        self.skins= {}
        self.skinDataFile= skinFile


    def _setModeFromInline(self, inline):
        wst= 0

        p= re.compile("^MAP([A-Z]|[0-9]){2}:{4}")
        if p.match(inline):
            self._processMapData(inline)
        elif inline.startswith("SKIN::::") :
            self._processSkinData(inline)
        else:
            l= inline.split(' ')
            for w in l:
                _w= w if not w.startswith('*') else w[1:]

                p= re.compile("^MAP([A-Z]|[0-9]){2}:{4}")
                if p.match(_w):
                    self._processMapData(_w)
                    continue
                if _w.startswith("SKIN::::") :
                    self._processSkinData(_w)
                    continue
                if _w=="MAP_LIST_DONE" :
                    wst= wst | 2
                    continue
                if _w=="SKIN_LIST_DONE":
                    wst= wst | 4
                    continue

                if _w=="MAPLOAD":
                    self.mode= self.MODE['NONE']
                    self.mode_manual= self.MODE['NONE']
                    self.ft= 0
                    wst= wst | 1
                    continue
                if _w in self.MODE.keys():
                    self.mode= self.mode | self.MODE[_w]
                    if w!=_w:
                        self.mode_manual= self.mode_manual | self.MODE[_w]
                    wst= wst | 1
                    continue
                p= re.compile("^FT([0-9]{1,3})")
                if p.match(_w):
                    self.ft= int(p.search(_w)[1])
                    wst= wst | 1
                    continue
        
        if wst & 1 :
            self._writeData()
        if wst & 2 :
            self._writeMapData()
        if wst & 4 :
            self._writeSkinData()


    def _processMapData(self, textData):
        sep="::::"
        mapData= textData.split(sep)
        if len(mapData)>=7 and len(mapData[0])==5 :
            mid= mapData[0][-2:]
            d= [mapData[1],mapData[2],mapData[3],None,None,None]
            
            for i in range(3,6):
                s_n= None
                try:
                    s_n= int(mapData[i+1])
                except ValueError:
                    print("Error parsing data for map '"+mid+"' (wrong value type, expected number…)")
                d[i]= s_n
            self.maps[mid]= d


    def _processSkinData(self, textData):
        sep="::::"
        skinData= textData.split(sep)
        if len(skinData)>= 5 and skinData[0]=="SKIN" and len(skinData[2])>0 :
            d= [skinData[1],None,None]
            
            for i in range(1,3):
                s_n= None
                try:
                    s_n= int(skinData[i+2])
                except ValueError:
                    print("Error parsing data for map '"+mid+"' (wrong value type, expected number…)")
                d[i]= s_n

            self.skins[skinData[2]]= d

    def _writeMapData(self):
        s= "{ \"maps\": {"

        json_bool_str= lambda b: 'true' if b else 'false'

        i= 0
        for M_Id in self.maps :
            s= s+(',' if i>0 else '')+"\n\t\""+str(M_Id)+"\": {\n"

            m= self.maps[M_Id]
            
            s= s+"\t\t\"title\":\t\""+m[0]+"\",\n"
            s= s+"\t\t\"zone\":\t\""+m[1]+"\",\n"
            s= s+"\t\t\"subtitle\":\t\""+m[2]+"\",\n"
            t="Discarded"
            if m[3]!=None :
                t= "Race" if (m[3]&8) else ("Battle" if (m[3]&16) else t) 
            s= s+"\t\t\"type\":\t\""+t+"\",\n"
            s= s+"\t\t\"sections\":\t"+json_bool_str(m[4]!=None and bool(m[4] & 32))+",\n"
            s= s+"\t\t\"hell\":\t"+json_bool_str(m[5]!=None and (m[5]%2>=1))+"\n"

            s= s+"\t}"

            i= i+1

        s= s+"\n} }"

        if self.mapDataFile!=None and len(self.mapDataFile)>0:
            mapfilename= os.path.basename(self.mapDataFile)
            mapfilepath= os.path.abspath(os.path.dirname(sys.argv[0]))+'/'+mapfilename
            mapf = open(mapfilepath, "w")
            mapf.write(s)
            mapf.close()
        else :
            print(s)


    def _writeSkinData(self):
        s= "{ \"skins\": {"

        i= 0
        for S_Name in self.skins :
            s= s+(',' if i>0 else '')+"\n\t\""+str(S_Name)+"\": {\n"

            sk= self.skins[S_Name]

            s=s+"\t\t\"realname\":\t\""+sk[0]+"\",\n"

            if sk[1]!=None:
                s=s+"\t\t\"speed\":\t\""+str(sk[1])+"\",\n"

            if sk[2]!=None:
                s=s+"\t\t\"weight\":\t\""+str(sk[2])+"\"\n"

            s= s+"\t}"

            i= i+1

        s= s+"\n} }"

        if self.skinDataFile!=None and len(self.skinDataFile)>0:
            skinfilename= os.path.basename(self.skinDataFile)
            skinfilepath= os.path.abspath(os.path.dirname(sys.argv[0]))+'/'+skinfilename
            skinf = open(skinfilepath, "w")
            skinf.write(s)
            skinf.close()
        else :
            print(s)


    def processLine(self, line):
        if (not line.startswith("<<<")):
            return False
        ll= len(self.id)
        if not ((line[3:(3+ll)]==self.id) and (line[(3+ll):(6+ll)]=="<<<")):
            return False
        lL= 6+ll
        if not line.endswith('>'*(lL)):
            return False
        
        within= ' '.join(filter((lambda e: len(e)>0), line[lL:(-lL)].split(' ')))
        self._setModeFromInline(within)

        return True

    def _writeData(self):
        s="{\"modes\": ["
        _b= False
        for k in self.MODE.keys():
            if (self.mode & self.MODE[k]):
                if _b:
                    s= s+', '
                s= s+"\""
                if (self.mode_manual & self.MODE[k]):
                    s=s+'*'
                s= s+k+"\""
                _b=True
        if self.ft>0:
            s= s+('; ' if _b else '')+"\"First To "+str(self.ft)+"\""
        s= s+"]}"

        if self.dataFile!=None and len(self.dataFile)>0:
                filename= os.path.basename(self.dataFile)
                filepath= os.path.abspath(os.path.dirname(sys.argv[0]))+'/'+filename
                f = open(filepath, "w")
                f.write(s)
                f.close()
        else :
            print(s)

        

if __name__ == "__main__":
    a1= sys.argv[1] if len(sys.argv)>1 else None
    a2= sys.argv[2] if len(sys.argv)>2 else None
    a3= sys.argv[3] if len(sys.argv)>3 else None


    data= StrashbotLogParser(a1, a2, a3)
    while True:
        line= sys.stdin.readline()

        if len(line) == 0:
            break
        else:
            data.processLine(line.replace('\n',''))



