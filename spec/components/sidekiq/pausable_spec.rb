require 'rails_helper'
require_dependency 'sidekiq/pausable'

describe Sidekiq do
  it "can pause and unpause" do
    Sidekiq.pause!
    expect(Sidekiq.paused?).to eq(true)
    Sidekiq.unpause!
    expect(Sidekiq.paused?).to eq(false)
  end
end
