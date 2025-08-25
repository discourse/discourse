# frozen_string_literal: true

RSpec.describe DiscourseId::Register do
  describe "#call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { { force: false } }
    let(:challenge_token) { "test_challenge_token_123" }
    let(:client_id) { "test_client_id" }
    let(:client_secret) { "test_client_secret" }
    let(:discourse_id_url) { "https://id.discourse.com" }

    fab!(:logo_upload) { Fabricate(:upload) }
    fab!(:logo_small_upload) { Fabricate(:upload) }

    before do
      SiteSetting.discourse_id_provider_url = discourse_id_url
      SiteSetting.title = "Test Forum"
      SiteSetting.site_description = "A test forum"
      SiteSetting.logo = logo_upload
      SiteSetting.logo_small = logo_small_upload
    end

    context "when already registered and force is false" do
      before do
        SiteSetting.discourse_id_client_id = client_id
        SiteSetting.discourse_id_client_secret = client_secret
      end

      it { is_expected.to fail_a_policy(:not_already_registered?) }
    end

    context "when already registered but force is true" do
      let(:params) { { force: true } }

      before do
        SiteSetting.discourse_id_client_id = client_id
        SiteSetting.discourse_id_client_secret = client_secret
      end

      context "when challenge request fails" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_raise(
            StandardError.new("Network error"),
          )
        end

        it { is_expected.to fail_a_step(:request_challenge) }
      end

      context "when challenge request returns non-200 status" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_return(
            status: 400,
            body: "Bad Request",
          )
        end

        it { is_expected.to fail_a_step(:request_challenge) }
      end

      context "when challenge response is invalid JSON" do
        before do
          stub_request(:post, "#{discourse_id_url}/challenge").to_return(
            status: 200,
            body: "invalid json",
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
          stub_request(:post, "#{discourse_id_url}/challenge").with(
            body: { domain: Discourse.current_hostname }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          ).to_return(
            status: 200,
            body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
          )
        end

        context "when registration request fails" do
          before do
            stub_request(:post, "#{discourse_id_url}/register").to_raise(
              StandardError.new("Connection timeout"),
            )
          end

          it { is_expected.to fail_a_step(:register_with_challenge) }
        end

        context "when registration returns non-200 status" do
          before do
            stub_request(:post, "#{discourse_id_url}/register").to_return(
              status: 422,
              body: "Validation failed",
            )
          end

          it { is_expected.to fail_a_step(:register_with_challenge) }
        end

        context "when registration response is invalid JSON" do
          before do
            stub_request(:post, "#{discourse_id_url}/register").to_return(
              status: 200,
              body: "not json",
            )
          end

          it { is_expected.to fail_a_step(:register_with_challenge) }
        end

        context "when registration succeeds" do
          let(:response_data) do
            { client_id: "new_client_id_123", client_secret: "new_client_secret_456" }
          end

          before do
            stub_request(:post, "#{discourse_id_url}/register").with(
              body: {
                client_name: SiteSetting.title,
                redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
                challenge_token: challenge_token,
                logo_uri: SiteSetting.site_logo_url,
                logo_small_uri: SiteSetting.site_logo_small_url,
                description: SiteSetting.site_description,
              }.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
            ).to_return(status: 200, body: response_data.to_json)
          end

          it { is_expected.to run_successfully }

          it "stores the challenge token in Redis" do
            result
            expect(Discourse.redis.get("discourse_id_challenge_token")).to eq(challenge_token)
          end

          it "stores credentials in SiteSetting" do
            result
            expect(SiteSetting.discourse_id_client_id).to eq("new_client_id_123")
            expect(SiteSetting.discourse_id_client_secret).to eq("new_client_secret_456")
          end

          it "enables Discourse ID" do
            expect { result }.to change { SiteSetting.enable_discourse_id }.to(true)
          end

          it "sets Redis expiration for challenge token" do
            result
            expect(Discourse.redis.ttl("discourse_id_challenge_token")).to be > 0
          end

          context "when site has no logo URLs" do
            before do
              SiteSetting.logo = nil
              SiteSetting.logo_small = nil

              stub_request(:post, "#{discourse_id_url}/register").with(
                body: {
                  client_name: SiteSetting.title,
                  redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
                  challenge_token: challenge_token,
                  description: SiteSetting.site_description,
                }.to_json,
              ).to_return(status: 200, body: response_data.to_json)
            end

            it "omits logo fields from registration request" do
              result
              expect(WebMock).to have_requested(:post, "#{discourse_id_url}/register").with { |req|
                body = JSON.parse(req.body)
                !body.key?("logo_uri") && !body.key?("logo_small_uri")
              }
            end
          end

          context "when site has no description" do
            before do
              SiteSetting.site_description = nil

              stub_request(:post, "#{discourse_id_url}/register").with(
                body: {
                  client_name: SiteSetting.title,
                  redirect_uri: "#{Discourse.base_url}/auth/discourse_id/callback",
                  challenge_token: challenge_token,
                  logo_uri: SiteSetting.site_logo_url,
                  logo_small_uri: SiteSetting.site_logo_small_url,
                }.to_json,
              ).to_return(status: 200, body: response_data.to_json)
            end

            it "omits description from registration request" do
              result
              expect(WebMock).to have_requested(:post, "#{discourse_id_url}/register").with { |req|
                body = JSON.parse(req.body)
                !body.key?("description")
              }
            end
          end
        end
      end
    end

    context "when not already registered" do
      before do
        SiteSetting.discourse_id_client_id = ""
        SiteSetting.discourse_id_client_secret = ""

        stub_request(:post, "#{discourse_id_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )

        stub_request(:post, "#{discourse_id_url}/register").to_return(
          status: 200,
          body: { client_id:, client_secret: }.to_json,
        )
      end

      it { is_expected.to run_successfully }

      it "completes the full registration flow" do
        result
        expect(SiteSetting.discourse_id_client_id).to eq(client_id)
        expect(SiteSetting.discourse_id_client_secret).to eq(client_secret)
        expect(SiteSetting.enable_discourse_id).to be(true)
      end
    end

    context "when using custom discourse_id_provider_url" do
      let(:custom_url) { "https://custom-id.example.com" }

      before do
        SiteSetting.discourse_id_provider_url = custom_url
        SiteSetting.discourse_id_client_id = ""
        SiteSetting.discourse_id_client_secret = ""

        stub_request(:post, "#{custom_url}/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: challenge_token }.to_json,
        )

        stub_request(:post, "#{custom_url}/register").to_return(
          status: 200,
          body: { client_id:, client_secret: }.to_json,
        )
      end

      it "uses the custom URL for requests" do
        result
        expect(WebMock).to have_requested(:post, "#{custom_url}/challenge")
        expect(WebMock).to have_requested(:post, "#{custom_url}/register")
      end
    end
  end
end
