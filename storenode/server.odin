package main

import "core:fmt"
import "core:net"
import "core:thread"
import "core:encoding/endian"
import "core:os"

Server :: struct {

}

new_server :: proc(allocator := context.allocator) -> ^Server {
    return new(Server, allocator)
}

server_start :: proc(s: ^Server) {
    // Start TCP Server
    local_endpoint := net.Endpoint {
        port = 8000,
        address = net.IP4_Loopback
    }

    local_socket, err := net.listen_tcp(local_endpoint)
    if err != nil {
        fmt.panicf("error starting listener: %s", err)
    }
    fmt.println("Server listening on port 8000")

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

    header_bytes: [8]byte
    _, err := net.recv_tcp(conn.socket, header_bytes[:])
    if err != nil {
        fmt.printfln("Error receiving packet header: %s", err)
        return
    }

    packet_type_b := header_bytes[:4]
    packet_size_b := header_bytes[4:]

    packet_type, _ := endian.get_u32(packet_type_b, endian.Byte_Order.Big)
    packet_size, _ := endian.get_u32(packet_size_b, endian.Byte_Order.Big)

    // make buffer
    buf, make_buf_err := make([]byte, packet_size)

    // read into buffer
    _, err = net.recv_tcp(conn.socket, buf)
    if err != nil {
        fmt.printfln("error reading data: %s", err)
    }

    create_file(buf)
}

// TODO: Create and add error return type
create_file :: proc(file_data: []byte) {    
    flags: int = os.O_WRONLY|os.O_CREATE

	mode: int = 0
    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }

	fd, _ := os.open("./data/file", flags, mode)
	defer os.close(fd)

	os.write(fd, file_data)
}