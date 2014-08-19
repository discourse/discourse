require 'spec_helper'
require_dependency 'sidekiq/pausable'

describe Sidekiq do
  it "can pause and unpause" do
    Sidekiq.pause!
    Sidekiq.paused?.should == true
    Sidekiq.unpause!
    Sidekiq.paused?.should == false
  end
end
