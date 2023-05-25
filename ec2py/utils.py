import os
import random
import string
import subprocess
import pyAesCrypt
import requests
import tarfile
import glob
import sys
from tempfile import gettempdir
from shutil import rmtree

def kill_proc(cmd):
    result = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, error = result.communicate()
    if result.returncode != 0: 
        error = "Error: %d %s %s" % (result.returncode, output.decode("utf-8"), error.decode("utf-8"))
        pass

def get_random_string():
    result_str = ''.join(random.choice(string.ascii_letters) for i in range(16))
    return result_str

def create_proc_ids_folder(folder):
    path = os.path.join(folder, 'procIDs')
    os.mkdir(path)

def get_list_files_in_folder(folder):
    path = os.path.join(folder, 'procIDs/*.txt')   
    files=glob.glob(path)   
    return files

def garbage_collector(folder):
    print("Starting garbage collector")
    files=get_list_files_in_folder(folder)
    if files:
        for file in files:
            os.remove(file)

def read_all_proc_ids(folder):
    proc_ids=None
    files=get_list_files_in_folder(folder)
    for file in files:     
        f=open(file, 'r')  
        proc_ids= f.readlines()
        f.close()
    return proc_ids


def get_instance_id():
    f = open("instance-id.txt", "r")
    return f.read()

def encrypt_file(password, pathfile):
    pyAesCrypt.encryptFile(pathfile, f"{pathfile}.enc", password)
    # decrypt
    #pyAesCrypt.decryptFile("data.txt.aes", "dataout.txt", password)
    return f"{pathfile}.enc"


def create_tmp_folder():
    tmp = os.path.join(gettempdir(), '{}'.format(hash(os.times()) % ((sys.maxsize + 1) * 2)))
    os.makedirs(tmp)
    return tmp + os.sep

def remove_tmp_folder(tmp):
    rmtree(tmp, ignore_errors=True)     



def getMyPublicIP():
    #return "3.94.232.39"
    return requests.get("http://169.254.169.254/latest/meta-data/public-ipv4").text


def compress_folder(folder):
    tar = tarfile.open(f"{folder}compress.tar.gz", "w:gz", format=tarfile.GNU_FORMAT)
    tar.add(folder, arcname="Output")
    tar.close()
    return f"{folder}compress.tar.gz"


