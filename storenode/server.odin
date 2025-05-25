package main

import "core:fmt"
import "core:net"
import "core:thread"
import "core:encoding/endian"
import "core:encoding/hex"
import "core:os"
import "core:crypto/sha3"
import "core:strings"

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
    all_data_buf, make_buf_err := make([]byte, packet_size)
    if make_buf_err != nil {
        fmt.printfln("error creating buffer for packet: %s", make_buf_err)
        return
    }
    defer delete(all_data_buf)

    // read into buffer
    _, err = net.recv_tcp(conn.socket, all_data_buf)
    if err != nil {
        fmt.printfln("error reading data from socket: %s", err)
        return
    }

    // Key Length (u32)
    key_size, _ := endian.get_u32(all_data_buf[:4], endian.Byte_Order.Big)

    // Read Key
    key := all_data_buf[4:4 + key_size]

    // Read File Data
    file_data := all_data_buf[4 + key_size:]

    // Hash Key
    sha_context: sha3.Context
    sha3.init_256(&sha_context)
    sha3.update(&sha_context, key)
    hash: [32]byte
    sha3.final(&sha_context, hash[:])

    // Encode Key Hash to Hex String
    hash_hex := hex.encode(hash[:])
    file_name, hex_clone_err := strings.clone_from_bytes(hash_hex)
    if hex_clone_err != nil {
        fmt.printfln("error cloning hash hex to string, %s", hex_clone_err)
        return
    }
    defer delete(file_name)

    create_file(file_name, file_data)
}

// TODO: Create and add error return type
create_file :: proc(file_name: string, file_data: []byte) {    
    flags: int = os.O_WRONLY|os.O_CREATE

	mode: int = 0
    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }

    file_path, concat_err := strings.concatenate({"./data/", file_name})
    if concat_err != nil {
        fmt.println("error concatenating file path parts: %s", concat_err)
        return
    }
    defer delete(file_path)

	fd, open_err := os.open(file_path, flags, mode)
    if open_err != nil {
        fmt.printfln("error opening file: %s", open_err)
    }
	defer os.close(fd)

	_, write_err := os.write(fd, file_data)
    if write_err != nil {
        fmt.printfln("error writing to file: %s", write_err)
    }
}