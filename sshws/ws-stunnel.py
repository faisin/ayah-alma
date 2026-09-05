#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Python WebSocket Proxy - by Ayah Alma

import socket
import threading
import select
import sys
import time
import getopt

LISTENING_ADDR='0.0.0.0'

if sys.argv[1:]:
    LISTENING_PORT=sys.argv[1]
else:
    LISTENING_PORT=2096

PASS=''

BUFLEN=4096*4
TIMEOUT=60

DEFAULT_HOST='127.0.0.1:109'

RESPONSE='HTTP/1.1 101 Ayah Alma Server Connected\r\nContent-Length: 104857600000\r\n\r\n'


class Server(threading.Thread):

    def __init__(self,host,port):
        super().__init__()

        self.running=False
        self.host=host
        self.port=port
        self.threads=[]
        self.threadsLock=threading.Lock()
        self.logLock=threading.Lock()


    def run(self):

        self.soc=socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        self.soc.setsockopt(
            socket.SOL_SOCKET,
            socket.SO_REUSEADDR,
            1
        )

        self.soc.settimeout(2)

        self.soc.bind(
            (
                self.host,
                int(self.port)
            )
        )

        self.soc.listen(100)

        self.running=True

        try:

            while self.running:

                try:

                    c,addr=self.soc.accept()

                    c.setblocking(True)

                except socket.timeout:
                    continue

                conn=ConnectionHandler(
                    c,
                    self,
                    addr
                )

                conn.start()

                self.addConn(conn)

        finally:

            self.running=False
            self.soc.close()


    def printLog(self,log):

        with self.logLock:

            print(log)


    def addConn(self,conn):

        with self.threadsLock:

            if self.running:

                self.threads.append(conn)


    def removeConn(self,conn):

        with self.threadsLock:

            if conn in self.threads:
                self.threads.remove(conn)


    def close(self):

        self.running=False

        with self.threadsLock:

            for c in list(self.threads):
                c.close()



class ConnectionHandler(threading.Thread):

    def __init__(self,socClient,server,addr):

        super().__init__()

        self.clientClosed=False
        self.targetClosed=True
        self.client=socClient
        self.client_buffer=b''

        self.server=server

        self.log='Connection: '+str(addr)


    def close(self):

        try:

            if not self.clientClosed:

                self.client.shutdown(
                    socket.SHUT_RDWR
                )

                self.client.close()

        except:
            pass

        self.clientClosed=True

        try:

            if not self.targetClosed:

                self.target.shutdown(
                    socket.SHUT_RDWR
                )

                self.target.close()

        except:
            pass

        self.targetClosed=True


    def run(self):

        try:

            self.client_buffer=(
                self.client.recv(BUFLEN)
                .decode(
                    errors='ignore'
                )
            )

            hostPort=self.findHeader(
                self.client_buffer,
                'X-Real-Host'
            )

            if hostPort=='':
                hostPort=DEFAULT_HOST

            split=self.findHeader(
                self.client_buffer,
                'X-Split'
            )

            if split!='':
                self.client.recv(BUFLEN)

            if hostPort!='':

                passwd=self.findHeader(
                    self.client_buffer,
                    'X-Pass'
                )

                if len(PASS)!=0 and passwd==PASS:

                    self.method_CONNECT(
                        hostPort
                    )

                elif len(PASS)!=0 and passwd!=PASS:

                    self.client.send(
                    b'HTTP/1.1 400 WrongPass!\r\n\r\n'
                    )

                elif hostPort.startswith(
                    '127.0.0.1'
                ) or hostPort.startswith(
                    'localhost'
                ):

                    self.method_CONNECT(
                        hostPort
                    )

                else:

                    self.client.send(
                    b'HTTP/1.1 403 Forbidden!\r\n\r\n'
                    )

            else:

                print(
                '- No X-Real-Host!'
                )

                self.client.send(
                b'HTTP/1.1 400 NoXRealHost!\r\n\r\n'
                )


        except Exception as e:

            self.log+=' error: '+str(e)

            self.server.printLog(
                self.log
            )


        finally:

            self.close()

            self.server.removeConn(
                self
            )


    def findHeader(self,head,header):

        aux=head.find(
            header+': '
        )

        if aux==-1:
            return ''

        aux=head.find(
            ':',
            aux
        )

        head=head[aux+2:]

        aux=head.find('\r\n')

        if aux==-1:
            return ''

        return head[:aux]


    def connect_target(self,host):

        i=host.find(':')

        if i!=-1:

            port=int(
                host[i+1:]
            )

            host=host[:i]

        else:

            port=443

        address=socket.getaddrinfo(
            host,
            port
        )[0][4]

        self.target=socket.socket()

        self.targetClosed=False

        self.target.connect(
            address
        )


    def method_CONNECT(self,path):

        self.log+=' CONNECT '+path

        self.connect_target(path)

        self.client.sendall(
            RESPONSE.encode()
        )

        self.server.printLog(
            self.log
        )

        self.doCONNECT()


    def doCONNECT(self):

        socs=[
            self.client,
            self.target
        ]

        count=0

        while True:

            count+=1

            recv,_,err=select.select(
                socs,
                [],
                socs,
                3
            )

            if err:
                break

            for sock in recv:

                try:

                    data=sock.recv(
                        BUFLEN
                    )

                    if not data:
                        return

                    if sock is self.target:

                        self.client.send(
                            data
                        )

                    else:

                        self.target.send(
                            data
                        )

                    count=0

                except:

                    return

            if count==TIMEOUT:
                return



def main():

    print("\n:---- Ayah Alma WebSocket Proxy ----:\n")

    print(
    "Listening addr: "+
    LISTENING_ADDR
    )

    print(
    "Listening port: "+
    str(LISTENING_PORT)
    )

    print(
    "\n:-----------------------------------:\n"
    )

    server=Server(
        LISTENING_ADDR,
        LISTENING_PORT
    )

    server.start()

    while True:

        time.sleep(60)


if __name__=="__main__":
    main()
