#!/bin/python3


import sys

import os
import os.path
from os import path

import re

import json

import math

import sqlite3

import glob

import requests


CLIPS_PER_PAGE= 30
DATABASE='./clips.db'


def __createTable(connection):
    r= True
    try:
        c = connection.cursor()
        c.execute(
            """ CREATE TABLE IF NOT EXISTS clips (
                id integer PRIMARY KEY,
                clipType text,
                url text,
                userId text,
                timestamp text,
                description text DEFAULT '',
                outdated interger DEFAULT 0 )
            """
        )
        connection.commit()
    except Error as e:
        r= False

    return r

def __createConnection():
    conn = None
    try:
        conn = sqlite3.connect(DATABASE)
    except Error as e:
        return None

    if bool(conn):
        if (not __createTable(conn)):
            print("ERROR::::Couldn't create database")

    return conn

def __generateJSONs(conn, dataDir):
    if not path.isdir(dataDir):
        print("ERROR::::bad dir")
        return 9

    try:
        files = glob.glob(dataDir+'/gallery*.json')
        for f in files:
            os.remove(f)
    except Error as e:
        print("ERROR::::error while removing files")
        return 11
    
    gallery_json_file= dataDir+'/gallery.json'
    
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM clips WHERE outdated = 0")
    l= c.fetchone()[0]

    with open(gallery_json_file, 'w+') as gallery_file:
        data= {"number": l, "entries_per_page": CLIPS_PER_PAGE}

        json.dump(data, gallery_file)

    c.execute("SELECT id, clipType, url, timestamp, description FROM clips WHERE outdated == 0 ORDER BY timestamp DESC")
    rows= c.fetchmany(30)
    _p=1
    while len(rows)>0 :
        gallery_json_file= dataDir+'/gallery'+str(_p)+'.json'

        data= {}
        for r in rows:
            data[r[0]]= {"type":r[1],"url":r[2], "description": r[4], "timestamp": r[3]}

        with open(gallery_json_file,'w+') as gallery_page_file:
            json.dump(data, gallery_page_file)

        _p+= 1
        rows= c.fetchmany(30)

    return 0


def __exract_vid(url,t):
    if t=='youtube':
        return re.search('.{11}$', url).group()
    elif t=='streamable.com':
        return re.search('\.com\/.*$', url).group()[5:]
    else:
        return None

def __url_check(url, t):
    try:
        checkurl= ("http://img.youtube.com/vi/"+__exract_vid(url)+"/mqdefault.jpg") if (t=='youtube')  else url
        r = requests.head(checkurl)
        return r.status_code == requests.codes.ok
    except Exception as e:
        return False

def _check_clips(dataDir):
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()

        cur.execute("SELECT id FROM clips WHERE outdated > 1")
        previously_expired= []
        rows= cur.fetchmany(30)
        while len(rows)>0 :
            for r in rows:
                previously_expired.append(r[0])

            rows= cur.fetchmany(30)

        cur.execute("SELECT id, clipType, url FROM clips")
        expired= {}
        rows= cur.fetchmany(30)
        while len(rows)>0 :
            for r in rows:
                if not __url_check(r[2], r[1]):
                    expired[r[0]]= r[2]

            rows= cur.fetchmany(30)

        if len(expired)>0:
            for k in expired:
                cur.execute("UPDATE clips SET outdated = 1 WHERE id = ?", (k,))
            conn.commit()

            try:
                files = glob.glob(dataDir+'/outdated.json')
                for f in files:
                    os.remove(f)
            except Error as e:
                print("ERROR::::error while removing files")
                return 11

            with open((dataDir+'/outdated.json'), 'w+') as outdated_json_file:
                json.dump(expired, outdated_json_file)

        rehabilitated= list(filter(lambda x : x not in expired, previously_expired))
        if len(rehabilitated)>0:
            for c_id in rehabilitated:
                cur.execute("UPDATE clips SET outdated = 0 WHERE id = ?", (c_id,))
            conn.commit()

        ret= 0
        if len(rehabilitated)>0 or len(expired)>0:
            ret= __generateJSONs(conn, dataDir)

        conn.close()

        return ret
    else:
        print("ERROR::::Can't establish connection with database")
        return 8





def _add_clip(dataDir, url, objType, userId, desc=""):
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT id FROM clips WHERE url = ?", (url,))
        f_row= cur.fetchone()
        if (f_row) and len(f_row)>0 :
            print("ALREADY_IN_DATABASE::::Same clip url exists::::"+str(f_row[0]))
            return 12

        if(desc and len(desc)>0):
            cur.execute(
                """ INSERT INTO clips(clipType, url, userId, description, timestamp)
                    VALUES (?,?,?,?,datetime('now'))
                """,
                (objType, url, userId, desc)
            )
        else:
            cur.execute(
                """ INSERT INTO clips(clipType, url, userId, timestamp)
                    VALUES (?,?,?,datetime('now'))
                """,
                (objType, url, userId)
            )
        conn.commit()
        c_id= cur.lastrowid

        ret= __generateJSONs(conn, dataDir)

        conn.close()

        return ret
    else:
        print("ERROR::::Can't establish connection with database")
        return 8

def _rm_clip(dataDir, clipId, userId):
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT * FROM clips WHERE id = ?", (int(clipId),))
        row= cur.fetchone()
        if not row:
            print("NO_SUCH_CLIP::::clip not found")
            conn.close()
            return 9
        cur.execute("SELECT * FROM clips WHERE id = ? AND userId = ?", (clipId, userId))
        row= cur.fetchone()
        if ((not row) and userId!='ADMIN'):
            print("BAD_USER::::clip cannot be deleted by this user")
            conn.close()
            return 10
        cur.execute("DELETE FROM clips WHERE id = ?", (clipId,))
        conn.commit()

        ret= __generateJSONs(conn, dataDir)

        conn.close()

        return ret
    else:
        print("ERROR::::Can't establish connection with database")
        return 8


def _processable_url(url):
    if re.match('^https?\:\/\/(w{3}\.)?.+\..{1,8}\/.*\.gif$', url):
        return 'gif'
    elif re.match('^https?\:\/\/(w{3}\.)?((youtube\.com.*(\?v=|\/embed\/))|(youtu\.be\/))(.{11})$', url):
        return 'youtube'
    elif re.match('^https?\:\/\/(w{3}\.)?streamable\.com\/(.*)?$', url):
        return 'streamable.com'
    else:
        return None
    
def _clip_info(clipId):
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT id, url, clipType, timestamp, userId, outdated FROM clips WHERE id = ?", (int(clipId),))
        row= cur.fetchone()
        if not row:
            print("NO_SUCH_CLIP::::clip not found")
            conn.close()
            return 9
        print("CLIP_INFO::::"+str(row[0])+"::::"+row[1]+"::::"+row[2]+"::::"+row[3]+"::::"+row[4]+"::::"+str(row[5]))
        conn.commit()
        conn.close()
        return 0
    else:
        print("ERROR::::Can't establish connection with database")
        return 8

def _edit_description(dataDir, clipId, userId, desc):
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT COUNT(*) FROM clips WHERE id = ?",(int(clipId),))
        n= cur.fetchone()[0]
        if (n<=0):
            print("NO_SUCH_CLIP::::clip not found")
            conn.close()
            return 9
        cur.execute("SELECT * FROM clips WHERE id = ? AND userId = ?", (int(clipId), userId))
        row= cur.fetchone()
        if ((not row) and userId!='ADMIN'):
            print("BAD_USER::::clip cannot be edited by this user")
            conn.close()
            return 10
        cur.execute("UPDATE clips SET description = ? WHERE id = ?", (desc,int(clipId)))
        conn.commit()

        ret=__generateJSONs(conn, dataDir)

        conn.close()
        return ret
    else:
        print("ERROR::::Can't establish connection with database")
        return 8

def _list_outdated():
    conn= __createConnection()
    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT id, timestamp, url FROM clips WHERE outdated >= 1")
        d={}
        rows= cur.fetchmany(30)
        while len(rows)>0 :
            for r in rows:
                d[r[0]]={"url": r[2], "timestamp": r[1]}
            rows= cur.fetchmany(30)

        print("OUTDATED_CLIPS::::"+str(len(d))+"::::"+json.dumps(d))
        return 0
    else:
        print("ERROR::::Can't establish connection with database")
        return 8




if __name__ == "__main__" :
    if len(sys.argv)<=1 :
        print("ERROR::::No target dir given")
        exit(1)
    elif not (path.exists(sys.argv[1]) and path.isdir(sys.argv[1])):
        print("ERROR::::bad target dir given")
        exit(2)
    d= sys.argv[1]

    if len(sys.argv)<=2 :
        print("ERROR::::No instruction given")
        exit(5)
    elif sys.argv[2]=="ADD":
        if  len(sys.argv)<=3 :
            print("ERROR::::object url must be provided")
            exit(3)
        else: 
            t= _processable_url(sys.argv[3])
            if not bool(t):
                print("UNSUPPORTED_TYPE::::unsupported object type")
                exit(4)
            elif len(sys.argv)<=4 :
                print("ERROR::::user id must be provided")
                exit(7)
            elif len(sys.argv)<=5:
                exit( _add_clip(d,sys.argv[3],t,sys.argv[4]))
            else:
                desc= ' '.join(sys.argv[5:])
                desc= (desc[:247]+'[…]') if (len(desc)>250) else desc
                exit( _add_clip(d,sys.argv[3],t,sys.argv[4],desc))
    elif sys.argv[2]=="RM":
        if  len(sys.argv)<=3 :
            print("ERROR::::clip id must be provided")
            exit(13)
        elif len(sys.argv)<=4 :
            print("ERROR::::user id must be provided")
            exit(7)
        else:
            exit(_rm_clip(d,sys.argv[3],sys.argv[4]))
    elif sys.argv[2]=="CHECK":
        exit(_check_clips(d))
    elif sys.argv[2]=="CLIP_INFO":
        if len(sys.argv)<=3 :
            print("ERROR::::clip id must be provided")
            exit(13)
        else:
            exit(_clip_info(sys.argv[3]))
    elif sys.argv[2]=="EDIT_DESCRIPTION":
        if len(sys.argv)<=3 :
            print("ERROR::::clip id must be provided")
            exit(13)
        elif len(sys.argv)<=4 :
            print("ERROR::::user id must be provided")
            exit(7)
        elif len(sys.argv)<=5:
            exit(_edit_description(d,sys.argv[3],sys.args[4],""))
        else:
            desc= ' '.join(sys.argv[5:])
            desc= (desc[:247]+'[…]') if (len(desc)>250) else desc
            exit(_edit_description(d,sys.argv[3],sys.args[4],desc))
    elif sys.argv[2]=="OUTDATED_CLIPS":
        exit (_list_outdated())

    else:
        print("ERROR::::Unknown instruction")
        exit(6)
