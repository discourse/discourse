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
    let(:discourse_id_url) { "https://id.discourse.com" }

    before do
      SiteSetting.discourse_id_provider_url = discourse_id_url
      SiteSetting.discourse_id_client_id = client_id
      SiteSetting.discourse_id_client_secret = client_secret
    end

    context "when credentials are not configured" do
      before do
        SiteSetting.discourse_id_client_id = ""
        SiteSetting.discourse_id_client_secret = ""
      end

      it { is_expected.to fail_a_policy(:credentials_configured?) }
    end

    context "when only client_id is missing" do
      before { SiteSetting.discourse_id_client_id = "" }

      it { is_expected.to fail_a_policy(:credentials_configured?) }
    end

    context "when only client_secret is missing" do
      before { SiteSetting.discourse_id_client_secret = "" }

      it { is_expected.to fail_a_policy(:credentials_configured?) }
    end

    context "when credentials are configured" do
      context "when challenge request fails" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_raise(
            StandardError.new("Network error"),
          )
        end

        it { is_expected.to fail_a_step(:request_challenge) }

        it "logs detailed error with context" do
          allow(Rails.logger).to receive(:error)
          result
          expect(Rails.logger).to have_received(:error).with(
            %r{Discourse ID regenerate credentials failed.*/challenge.*Network error}m,
          )
        end
      end

      context "when challenge request returns non-200 status" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_return(
            status: 503,
            body: "Service Unavailable",
          )
        end

        it { is_expected.to fail_a_step(:request_challenge) }
      end

      context "when challenge response has domain mismatch" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_return(
            status: 200,
            body: { domain: "wrong-domain.com", token: challenge_token }.to_json,
          )
        end

        it { is_expected.to fail_a_step(:request_challenge) }
      end

      context "when challenge request succeeds" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_return(
            status: 200,
            body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
          )
        end

        context "when regenerate request fails" do
          before do
            stub_request(:post, "#{discourse_id_url}/regenerate").to_raise(
              StandardError.new("Connection timeout"),
            )
          end

          it { is_expected.to fail_a_step(:regenerate_with_challenge) }

          it "logs detailed error with context" do
            allow(Rails.logger).to receive(:error)
            result
            expect(Rails.logger).to have_received(:error).with(
              %r{Discourse ID regenerate credentials failed.*/regenerate.*Connection timeout}m,
            )
          end
        end

        context "when regenerate request returns non-200 status" do
          before do
            stub_request(:post, "#{discourse_id_url}/regenerate").to_return(
              status: 401,
              body: "Unauthorized",
            )
          end

          it { is_expected.to fail_a_step(:regenerate_with_challenge) }
        end

        context "when regenerate response is invalid JSON" do
          before do
            stub_request(:post, "#{discourse_id_url}/regenerate").to_return(
              status: 200,
              body: "not json",
            )
          end

          it { is_expected.to fail_a_step(:regenerate_with_challenge) }
        end

        context "when regenerate request succeeds" do
          before do
            stub_request(:post, "#{discourse_id_url}/regenerate").with(
              body: { client_id:, client_secret:, challenge_token: }.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
            ).to_return(status: 200, body: { client_id:, client_secret: new_client_secret }.to_json)
          end

          it { is_expected.to run_successfully }

          it "stores the challenge token in Redis" do
            result
            expect(Discourse.redis.get("discourse_id_challenge_token")).to eq(challenge_token)
          end

          it "updates the client_secret in SiteSetting" do
            result
            expect(SiteSetting.discourse_id_client_secret).to eq(new_client_secret)
          end

          it "does not change the client_id" do
            result
            expect(SiteSetting.discourse_id_client_id).to eq(client_id)
          end

          it "logs the action" do
            expect { result }.to change {
              UserHistory.where(action: UserHistory.actions[:custom_staff]).count
            }.by(1)

            log = UserHistory.last
            expect(log.custom_type).to eq("discourse_id_regenerate_credentials")
            expect(log.details).to include(DiscourseId.masked_client_id)
          end
        end
      end
    end

    context "when using custom discourse_id_provider_url" do
      let(:custom_url) { "https://custom-id.example.com" }

      before do
        SiteSetting.discourse_id_provider_url = custom_url

        stub_request(:post, "#{custom_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )

        stub_request(:post, "#{custom_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: new_client_secret }.to_json,
        )
      end

      it "uses the custom URL for requests" do
        result
        expect(WebMock).to have_requested(:post, "#{custom_url}/challenge")
        expect(WebMock).to have_requested(:post, "#{custom_url}/regenerate")
      end
    end

    context "when site has a base_path" do
      let(:path) { "/forum" }

      before do
        allow(Discourse).to receive(:base_path).and_return(path)

        stub_request(:post, "#{discourse_id_url}/challenge").with(
          body: { domain: Discourse.current_hostname, path: }.to_json,
        ).to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, path:, token: challenge_token }.to_json,
        )

        stub_request(:post, "#{discourse_id_url}/regenerate").to_return(
          status: 200,
          body: { client_id:, client_secret: new_client_secret }.to_json,
        )
      end

      it "includes path in challenge request" do
        result
        expect(WebMock).to have_requested(:post, "#{discourse_id_url}/challenge").with { |req|
          JSON.parse(req.body)["path"] == path
        }
      end

      it { is_expected.to run_successfully }
    end
  end
end
