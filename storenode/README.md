# Store Node
Holds chunked data sent from the core node.

## Protocol
### Packet Structure
A basic packet is structured with a header, containing the protocol type and packet length.

The header is made up of 8 bytes, 4 for the packet type, and 4 to contain the packet length (in bytes).

### Send Data Packet (0x00)
Contains raw byte data for the file chunk being written.

### Get Data Packet (0x01)
Requests data for a file chunk.