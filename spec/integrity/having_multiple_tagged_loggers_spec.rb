# frozen_string_literal: true

RSpec.describe "Having multiple tagged loggers", type: :request do
  let(:loggers) { 2.times.map { ActiveSupport::TaggedLogging.new(Logger.new(nil)) } }

  before { loggers.each { Rails.logger.broadcast_to(it) } }

  after { loggers.each { Rails.logger.stop_broadcasting_to(it) } }

  it "does not execute request twice" do
    expect_any_instance_of(SilenceLogger).to receive(:call_app).once.and_call_original
    get "/user_actions.json"
  end
end
