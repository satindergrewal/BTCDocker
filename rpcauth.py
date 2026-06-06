#!/usr/bin/env python3
# Generates rpcauth credentials for bitcoin.conf
# From Bitcoin Core: https://github.com/bitcoin/bitcoin/blob/master/share/rpcauth/rpcauth.py

import hashlib
import hmac
import os
import base64
import sys

def generate(username):
    salt = os.urandom(16).hex()
    password = base64.urlsafe_b64encode(os.urandom(24)).decode()
    hmac_hash = hmac.new(salt.encode(), password.encode(), hashlib.sha256).hexdigest()
    print(f"\nPaste this into bitcoin.conf:")
    print(f"  rpcauth={username}:{salt}${hmac_hash}\n")
    print(f"Paste this into fulcrum.conf as bitcoind-password:")
    print(f"  {password}\n")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} <username>")
        sys.exit(1)
    generate(sys.argv[1])
