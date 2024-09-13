#!/bin/python3


import sys

import math

import datetime


import sqlite3


from pymongo import MongoClient





sqlite_database_file="./clips.db"


MONGO_CONNECTION_STRING = "mongodb://__USERNAME__:__PASSWORD__@__HOST__/__DBNAME__"
mongo_username="strashbot"
mongo_password="Zpas5wordX_"
mongo_host="localhost"
mongo_db_name="strashbotkarting_db"

MONGO_KART_CLIPS_COLLECTION_STRING="clips"
MONGO_KART_COUNTERS_COLLECTION_STRING="counters"
# TODO: update counters afterwards...



def __createSQLConnection():
    conn = None
    try:
        conn = sqlite3.connect(sqlite_database_file)
    except Error as e:
        return None

    return conn

def _get_SQLclipPage(pageNum=1, pageSize=30):
    conn= __createSQLConnection()

    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT * FROM clips ORDER BY id LIMIT "+str(pageSize)+" OFFSET "+str((pageNum-1)*pageSize))
        f_rows= cur.fetchall()
        
        return f_rows
    else:
        return None

def _get_numberOfSQLClips():
    conn= __createSQLConnection()

    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT count(*) FROM clips")
        count= cur.fetchone()[0]
        
        return count
    else:
        return None

def _get_SQLclipMaxID():
    conn= __createSQLConnection()

    if (conn):
        cur= conn.cursor()
        cur.execute("SELECT MAX(id) FROM clips")
        return cur.fetchone()[0]
    else:
        return None


def __get_mongo_connection_str():
    return MONGO_CONNECTION_STRING.replace(
        "__USERNAME__", mongo_username
    ).replace(
        "__PASSWORD__", mongo_password
    ).replace(
        "__HOST__", mongo_host
    ).replace(
        "__DBNAME__", mongo_db_name
    )

def _get_mongo_database():
    client = MongoClient(__get_mongo_connection_str())

    # Create the database for our example (we will use the same database throughout the tutorial
    return client[mongo_db_name]

def _insert_clips_in_mongoDB(clips):
    clip_objs= []
    for clip in clips:
        clip_obj= {
            "_id" : clip[0],
            "type" : clip[1],
            "url" : clip[2],
            "submitter_id" : clip[3],
            "timestamp" : datetime.datetime.strptime(clip[4],'%Y-%m-%d %H:%M:%S'),
            "description" : clip[5],
            "thumbnail" : ""
        }

        print(f"===> found {clip_obj}")

        clip_objs.append(clip_obj)

    db= _get_mongo_database()
    clip_collection= db[MONGO_KART_CLIPS_COLLECTION_STRING]

    clip_collection.insert_many(clip_objs)

def _update_MongoClipIDCounter():
    max= _get_SQLclipMaxID()

    if(max):
        print(f"==> updating counters DB ({max})…")
        db= _get_mongo_database()
        counters_collection= db[MONGO_KART_COUNTERS_COLLECTION_STRING]

        query= { "_id" : MONGO_KART_CLIPS_COLLECTION_STRING }
        counters_collection.update_one(
            query,
            { "$set": { "seq_number": max } }
        )


    

if __name__ == "__main__":
    if len(sys.argv)<6:
        print("Usage:\n")
        print(f"\t{sys.argv[0]} sql_db_file username password host database_name")

        exit(1)
    else:
        sqlite_database_file= sys.argv[1]

        mongo_username= sys.argv[2]
        mongo_password= sys.argv[3]
        mongo_host= sys.argv[4]
        mongo_db_name= sys.argv[5]

        print(f"=> from: '{sqlite_database_file}'  to: '{__get_mongo_connection_str()}'")

        n= _get_numberOfSQLClips()
        p_s= 30
        p_n= math.ceil(n/p_s)
        print(f"=> found {n} clips => {p_n} pages of {p_s}")

        for _p in range(0,p_n):
            p= _p+1
            print(f"==> migration clips page {p} …")
            clips= _get_SQLclipPage(p, p_s)

            _insert_clips_in_mongoDB(clips)

        _update_MongoClipIDCounter()

        exit(0)



