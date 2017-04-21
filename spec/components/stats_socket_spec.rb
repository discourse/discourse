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

    parsed = JSON.parse(line)

    expect(parsed.keys.sort).to eq(GC.stat.keys.map(&:to_s).sort)
  end

end
