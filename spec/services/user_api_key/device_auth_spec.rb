# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth do
  describe ".trace" do
    it "does not raise when an event subscriber raises" do
      listener = ->(*) { raise "boom" }
      DiscourseEvent.on(described_class::TRACE_EVENT, &listener)

      expect {
        described_class.trace("device_auth.test", device_code: SecureRandom.hex(32))
      }.not_to raise_error
    ensure
      DiscourseEvent.off(described_class::TRACE_EVENT, &listener)
    end

    it "reports when verbose logging fails" do
      SiteSetting.verbose_user_api_key_device_auth_logging = true
      allow(Rails.logger).to receive(:info).and_raise("boom")
      allow(Discourse).to receive(:warn_exception)

      expect {
        described_class.trace("device_auth.test", device_code: SecureRandom.hex(32))
      }.not_to raise_error
      expect(Discourse).to have_received(:warn_exception).with(
        an_instance_of(RuntimeError),
        message: "User API key device auth trace failed",
        env: {
          event: "device_auth.test",
        },
      )
    end

    it "truncates string payload values" do
      SiteSetting.verbose_user_api_key_device_auth_logging = true
      logged_message = nil
      allow(Rails.logger).to receive(:info) { |message| logged_message = message }

      described_class.trace("device_auth.test", client_id: "x" * 300)

      logged_payload = JSON.parse(logged_message)
      expect(logged_payload["client_id"]).to eq("x" * described_class::TRACE_MAX_VALUE_LENGTH)
    end
  end
end
