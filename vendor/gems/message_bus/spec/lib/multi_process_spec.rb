require 'spec_helper'
require 'message_bus'

describe MessageBus::ReliablePubSub do

  def new_bus
    MessageBus::ReliablePubSub.new(:db => 10)
  end

  def work_it
    Signal.trap("HUP") { exit }

    bus = new_bus
    $stdout.reopen("/dev/null", "w")
    $stderr.reopen("/dev/null", "w")
    # subscribe blocks, so we need a new bus to transmit
    new_bus.subscribe("/echo", 0) do |msg|
      bus.publish("/response", Process.pid.to_s)
    end
  end

  def spawn_child
    r = fork
    if r.nil?
      work_it
    else
      r
    end
  end

  it 'gets every response from child processes' do
    pid = nil
    Redis.new(:db => 10).flushdb
    begin
      pids = (1..10).map{spawn_child}
      responses = []
      bus = MessageBus::ReliablePubSub.new(:db => 10)
      Thread.new do
        bus.subscribe("/response", 0) do |msg|
          responses << msg if pids.include? msg.data.to_i
        end
      end
      10.times{bus.publish("/echo", Process.pid.to_s)}
      wait_for 4000 do
        responses.count == 100
      end

      # p responses.group_by(&:data).map{|k,v|[k, v.count]}
      # p responses.group_by(&:global_id).map{|k,v|[k, v.count]}
      responses.count.should == 100
    ensure
      if pids
        pids.each do |pid|
          Process.kill("HUP", pid)
          Process.wait(pid)
        end
      end
    end
  end
end
