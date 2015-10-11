require 'rails_helper'
require 'demon/base'

describe Demon do

  class RudeDemon < Demon::Base
    def self.prefix
      "rude"
    end

    def after_fork
      Signal.trap("HUP"){}
      Signal.trap("TERM"){}
      sleep 999999
    end
  end

  it "can terminate rude demons" do

    skip("forking rspec has side effects")
    # Forking rspec has all sorts of weird side effects
    #  this spec works but we must skip it to keep rspec
    #  state happy


    RudeDemon.start
    _,demon = RudeDemon.demons.first
    pid = demon.pid
    wait_for {
      demon.alive?
    }

    demon.stop_timeout = 0.05
    demon.stop
    demon.start

    running = !!(Process.kill(0, pid)) rescue false
    expect(running).to eq(false)
  end
end
