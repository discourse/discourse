# frozen_string_literal: true

RSpec.describe UserApiKeyClientsController do
  let :public_key do
    <<~TXT
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDh7BS7Ey8hfbNhlNAW/47pqT7w
    IhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFV
    p16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0n
    w0z/BYpOgZ8QwnI5ZwIDAQAB
    -----END PUBLIC KEY-----
    TXT
  end

  let :args do
    {
      client_id: "x" * 32,
      auth_redirect: "http://over.the/rainbow",
      application_name: "foo",
      public_key: public_key,
    }
  end

  describe "#register" do
    context "without scopes" do
      it "returns a 400" do
        post "/user-api-key-client/register.json", params: args
        expect(response.status).to eq(400)
      end
    end

    context "with scopes" do
      let!(:args_with_scopes) { args.merge(scopes: "user_status") }

      context "when scopes are not allowed" do
        before { SiteSetting.allow_user_api_key_client_scopes = "" }

        it "returns a 403" do
          post "/user-api-key-client/register.json", params: args_with_scopes
          expect(response.status).to eq(403)
        end
      end

      context "when scopes are allowed" do
        before { SiteSetting.allow_user_api_key_client_scopes = "user_status" }

        it "registers a client" do
          post "/user-api-key-client/register.json", params: args_with_scopes
          expect(response.status).to eq(200)
          client =
            UserApiKeyClient.find_by(
              client_id: args_with_scopes[:client_id],
              application_name: args_with_scopes[:application_name],
              auth_redirect: args_with_scopes[:auth_redirect],
              public_key: args_with_scopes[:public_key],
            )
          expect(client.present?).to eq(true)
          expect(client.scopes.map(&:name)).to match_array(["user_status"])
        end

        context "if the client is already registered" do
          before { Fabricate(:user_api_key_client, **args) }

          it "returns a 403" do
            post "/user-api-key-client/register.json", params: args_with_scopes
            expect(response.status).to eq(403)
          end
        end
      end
    end
  end
end
