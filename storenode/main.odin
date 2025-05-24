package main

import "core:fmt"
import "core:net"
import "core:thread"

main :: proc() {
    // Start TCP Server
    local_endpoint := net.Endpoint {
        port = 8000,
        address = net.IP4_Loopback
    }

    local_socket, err := net.listen_tcp(local_endpoint)
    if err != nil {
        fmt.panicf("error starting listener: %s", err)
    }

    // Accept Connections
    for {
        // Accept connection
        remote_socket, remote_endpoint, err := net.accept_tcp(local_socket)
        if err != nil {
            fmt.printfln("Error accepting connection: %s", err)
        }

        // TODO: maybe adjust this to a thread-pool?

        // Create thread
        t := thread.create(thread_proc)
        thread_data := Thread_Data {
            conn = &{
                socket = remote_socket,
                endpoint = remote_endpoint,
            }
        }
        t.data = &thread_data
        
        // Start thread
        thread.start(t)
    }
}

Thread_Data :: struct {
    conn: ^Conn,
}

thread_proc :: proc(t: ^thread.Thread) {
    data := cast(^Thread_Data)t.data

    handle_conn(data.conn)
}

Conn :: struct {
    socket: net.TCP_Socket,
    endpoint: net.Endpoint,
}

handle_conn :: proc(conn: ^Conn) {
    defer net.close(conn.socket)
}