#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Python WebSocket Proxy (Port 2082) - by Ayah Alma

import socket
import threading
import select
import sys
import time

LISTENING_ADDR='0.0.0.0'

if sys.argv[1:]:
    LISTENING_PORT=sys.argv[1]
else:
    LISTENING_PORT=2082

PASS=''

BUFLEN=4096*4
TIMEOUT=60

DEFAULT_HOST='127.0.0.1:109'

RESPONSE='HTTP/1.1 101 Switching Protocols\r\nContent-Length: 104857600000\r\n\r\n'


class Server(threading.Thread):

    def __init__(self,host,port):
        super().__init__()

        self.host=host
        self.port=port
        self.running=True

    def run(self):

        self.soc=socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        self.soc.setsockopt(
            socket.SOL_SOCKET,
            socket.SO_REUSEADDR,
            1
        )

        self.soc.bind(
            (
                self.host,
                int(self.port)
            )
        )

        self.soc.listen(100)

        while self.running:

            try:

                c,addr=self.soc.accept()

                ConnectionHandler(
                    c,
                    addr
                ).start()

            except:
                pass


class ConnectionHandler(threading.Thread):

    def __init__(self,client,addr):

        super().__init__()

        self.client=client
        self.addr=addr


    def run(self):

        try:

            self.client.recv(BUFLEN)

            host,port=DEFAULT_HOST.split(":")

            target=socket.create_connection(
                (
                    host,
                    int(port)
                )
            )

            self.client.send(
                RESPONSE.encode()
            )

            while True:

                recv,_,_=select.select(
                    [
                        self.client,
                        target
                    ],
                    [],
                    [],
                    TIMEOUT
                )

                if not recv:
                    break

                for sock in recv:

                    data=sock.recv(
                        BUFLEN
                    )

                    if not data:
                        return

                    if sock==self.client:

                        target.sendall(
                            data
                        )

                    else:

                        self.client.sendall(
                            data
                        )

        except Exception as e:

            print(
                "ERR:",
                str(e)
            )


        finally:

            try:
                self.client.close()
            except:
                pass


if __name__ == "__main__":
    print("\n:---- Ayah Alma WS Proxy (2082) ----:\n")
    Server(
        LISTENING_ADDR,
        LISTENING_PORT
    ).start()

    while True:
        time.sleep(60)

