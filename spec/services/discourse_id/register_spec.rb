# frozen_string_literal: true

RSpec.describe DiscourseId::Register do
  describe "#call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { { force: false } }
    let(:discourse_id_url) { "https://id.discourse.com" }
    let(:challenge_token) { "test-challenge-token" }
    let(:registration_data) do
      { "client_id" => "test-client-id", "client_secret" => "test-client-secret" }
    end

    before do
      SiteSetting.title = "Test Site"
      # Skip site setting validation for tests
      allow(SiteSetting).to receive(:enable_discourse_id).and_return(true)
      allow(SiteSetting).to receive(:enable_discourse_id=)
    end

    context "when discourse_id is not enabled" do
      before { allow(SiteSetting).to receive(:enable_discourse_id).and_return(false) }

      it { is_expected.to fail_a_policy(:discourse_id_enabled) }
    end

    context "when already registered and not forcing" do
      before do
        allow(SiteSetting).to receive(:discourse_id_client_id).and_return("existing-client-id")
        allow(SiteSetting).to receive(:discourse_id_client_secret).and_return(
          "existing-client-secret",
        )
      end

      it { is_expected.to fail_a_step(:validate_not_already_registered) }
    end

    context "when challenge request succeeds" do
      before do
        allow(SiteSetting).to receive(:discourse_id_client_id).and_return("")
        allow(SiteSetting).to receive(:discourse_id_client_secret).and_return("")
        allow(SiteSetting).to receive(:discourse_id_client_id=)
        allow(SiteSetting).to receive(:discourse_id_client_secret=)

        stub_request(:post, "#{discourse_id_url}/challenge").to_return(
          status: 200,
          body: { token: challenge_token }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

        stub_request(:post, "#{discourse_id_url}/register").to_return(
          status: 200,
          body: registration_data.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )
      end

      it { is_expected.to run_successfully }

      it "stores credentials" do
        allow(SiteSetting).to receive(:discourse_id_client_id=)
        allow(SiteSetting).to receive(:discourse_id_client_secret=)

        result

        expect(SiteSetting).to have_received(:discourse_id_client_id=).with("test-client-id")
        expect(SiteSetting).to have_received(:discourse_id_client_secret=).with(
          "test-client-secret",
        )
      end
    end

    context "when challenge request fails" do
      before do
        allow(SiteSetting).to receive(:discourse_id_client_id).and_return("")
        allow(SiteSetting).to receive(:discourse_id_client_secret).and_return("")

        stub_request(:post, "#{discourse_id_url}/challenge").to_return(
          status: 400,
          body: "Bad Request",
        )
      end

      it { is_expected.to fail_a_step(:request_challenge) }
    end
  end
end
