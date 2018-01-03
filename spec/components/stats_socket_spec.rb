require 'rails_helper'
require_dependency 'stats_socket'

describe StatsSocket do
  let :socket_path do
    "#{Dir.tmpdir}/#{SecureRandom.hex}"
  end

  let :stats_socket do
    StatsSocket.new(socket_path)
  end

  before do
    stats_socket.start
  end

  after do
    stats_socket.stop
  end

  it "can respond to various stats commands" do
    line = nil

    # ensure this works more than once :)
    2.times do
      socket = UNIXSocket.new(socket_path)
      socket.send "gc_stat\n", 0
      line = socket.readline
      socket.close
    end

    socket = UNIXSocket.new(socket_path)
    socket.send "gc_st", 0
    socket.flush
    sleep 0.001
    socket.send "at\n", 0
    line = socket.readline
    socket.close

    parsed = JSON.parse(line)

    expect(parsed.keys.sort).to eq(GC.stat.keys.map(&:to_s).sort)

    # make sure we have libv8 going
    PrettyText.cook("x")

    socket = UNIXSocket.new(socket_path)
    socket.send "v8_stat\n", 0
    line = socket.readline
    socket.close

    parsed = JSON.parse(line)

    expect(parsed['total_physical_size']).to be > (0)
  end

end
