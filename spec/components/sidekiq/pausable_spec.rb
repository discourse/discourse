require 'spec_helper'
require_dependency 'sidekiq/pausable'

describe Sidekiq do
  it "can pause and unpause" do

    # Temporary work around

    t = Thread.new do
      Sidekiq.pause!
      Sidekiq.paused?.should == true
      Sidekiq.unpause!
      Sidekiq.paused?.should == false
    end

    t2 = Thread.new do
      sleep 5
      t.kill
    end

    t.join
    if t2.alive?
      t2.kill
    else
      raise "Timed out running sidekiq pause test"
    end

  end
end
