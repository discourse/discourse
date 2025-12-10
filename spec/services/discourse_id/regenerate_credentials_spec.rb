# frozen_string_literal: true

RSpec.describe DiscourseId::RegenerateCredentials do
  describe "#call" do
    subject(:result) { described_class.call(guardian:) }

    fab!(:admin)

    let(:guardian) { Guardian.new(admin) }
    let(:challenge_token) { SecureRandom.hex }
    let(:client_id) { SecureRandom.hex }
    let(:client_secret) { SecureRandom.hex }
    let(:new_client_secret) { SecureRandom.hex }
    let(:provider_url) { DiscourseId.provider_url }

    before do
      SiteSetting.discourse_id_client_id = client_id
      SiteSetting.discourse_id_client_secret = client_secret
    end

    context "when credentials are not configured" do
      before { SiteSetting.discourse_id_client_id = "" }

      it { is_expected.to fail_a_policy(:credentials_configured?) }
    end

    context "when challenge request fails" do
      before { stub_request(:post, "#{provider_url}/challenge").to_return(status: 503) }

      it { is_expected.to fail_a_step(:request_challenge) }
    end

    context "when challenge response has domain mismatch" do
      before do
        stub_request(:post, "#{provider_url}/challenge").to_return(
          status: 200,
          body: { domain: "wrong-domain.com", token: challenge_token }.to_json,
        )
      end

      it { is_expected.to fail_a_step(:request_challenge) }
    end

    context "when regenerate request fails" do
      before do
        stub_request(:post, "#{provider_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )
        stub_request(:post, "#{provider_url}/regenerate").to_return(status: 401)
      end

      it { is_expected.to fail_a_step(:regenerate_with_challenge) }
    end

    context "when successful" do
      before do
        stub_request(:post, "#{provider_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )
        stub_request(:post, "#{provider_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: new_client_secret }.to_json,
        )
      end

      it { is_expected.to run_successfully }

      it "updates the client_secret and logs the action" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_staff]).count
        }.by(1)

        expect(SiteSetting.discourse_id_client_secret).to eq(new_client_secret)
        expect(UserHistory.last.custom_type).to eq("discourse_id_regenerate_credentials")
      end
    end

    context "when site has a base_path" do
      before do
        allow(Discourse).to receive(:base_path).and_return("/forum")
        stub_request(:post, "#{provider_url}/challenge").to_return(
          status: 200,
          body: {
            domain: Discourse.current_hostname,
            path: "/forum",
            token: challenge_token,
          }.to_json,
        )
        stub_request(:post, "#{provider_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: new_client_secret }.to_json,
        )
      end

      it "includes path in challenge request" do
        result
        expect(WebMock).to have_requested(:post, "#{provider_url}/challenge").with { |req|
          JSON.parse(req.body)["path"] == "/forum"
        }
      end
    end
  end
end
