# frozen_string_literal: true

RSpec.describe SignalTrapLogger do
  describe "#log" do
    it "should queue up messages to be logged which will then be logged by the logging thread" do
      fake_logger = FakeLogger.new

      SignalTrapLogger.instance.log(fake_logger, "message 1", level: :error)

      # Ensures that thread doesn't die even if an error is encountered
      SignalTrapLogger.instance.log(fake_logger, "error", level: :abcdes)

      SignalTrapLogger.instance.log(fake_logger, "message 2", level: :info)

      wait_for { fake_logger.errors.size == 1 && fake_logger.infos.size == 1 }

      expect(fake_logger.errors).to eq(["message 1"])
      expect(fake_logger.infos).to eq(["message 2"])
    end
  end
end
