# frozen_string_literal: true

# Patch getaddrinfo to recognize `FinalDestination::Connector` tokens
# and return their IPs instead of doing a true lookup.
module FinalDestinationAddrinfoPatch
  def getaddrinfo(nodename, service, family = nil, *args, **kwargs)
    return super unless FinalDestination::Connector.token?(nodename)

    ips =
      FinalDestination::Connector.addresses_for_family(
        FinalDestination::Connector.addresses(nodename),
        family,
      )
    raise SocketError, "getaddrinfo: Address family for hostname not supported" if ips.empty?

    ips.map { |ip| Addrinfo.tcp(ip, service.to_i) }
  end
end

# TCPSocket.open uses a C-based implementation by default, which would bypass our
# getaddrinfo patch. Instead, open the socket with `Socket.tcp`, then set up a `TCPSocket`
# instance with the result.
module FinalDestinationTCPSocketPatch
  # Takes *args because TCPServer inherits this singleton method and
  # `TCPServer.open(port)` has fewer arguments — a fixed host/port signature
  # fails the arity check before `super` can run. A bare `super` forwards the
  # original arguments untouched.
  def open(*args, **kwargs)
    host = args[0]
    return super unless FinalDestination::Connector.token?(host)

    _, port, local_host, local_port = args

    socket =
      Socket.tcp(
        host,
        port,
        local_host,
        local_port,
        connect_timeout: kwargs[:open_timeout],
        fast_fallback: true,
      )
    socket.autoclose = false # Let the TCPSocket handle closing

    TCPSocket.for_fd(socket.fileno)
  end
end

Addrinfo.singleton_class.prepend(FinalDestinationAddrinfoPatch)
TCPSocket.singleton_class.prepend(FinalDestinationTCPSocketPatch)
