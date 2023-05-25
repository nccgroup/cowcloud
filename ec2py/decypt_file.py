import pyAesCrypt
import os
import sys

original = os.getcwd() + os.sep + "compress_and_encrypted.tar.gz.enc"
final = os.getcwd() + os.sep + "compress_and_encrypted.tar.gz"

# pass the password as an argument
pyAesCrypt.decryptFile(original, final, sys.argv[1])
