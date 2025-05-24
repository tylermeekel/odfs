package main

import "core:fmt"
import "core:net"
import "core:thread"

main :: proc() {
    server := new_server()
    server_start(server)
}