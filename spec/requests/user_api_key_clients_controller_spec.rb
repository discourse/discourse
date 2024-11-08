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
    context "without a user" do
      it "returns a 403" do
        post "/user-api-key-client/register.json", params: args
        expect(response.status).to eq(403)
      end
    end

    context "with a user" do
      before { sign_in(Fabricate(:user)) }

      it "registers a client" do
        post "/user-api-key-client/register.json", params: args
        expect(response.status).to eq(200)
        expect(
          UserApiKeyClient.exists?(
            client_id: args[:client_id],
            application_name: args[:application_name],
            auth_redirect: args[:auth_redirect],
            public_key: args[:public_key],
          ),
        ).to eq(true)
      end

      it "updates a registered client" do
        Fabricate(:user_api_key_client, **args)
        args[:application_name] = "bar"
        post "/user-api-key-client/register.json", params: args
        expect(response.status).to eq(200)
        expect(
          UserApiKeyClient.exists?(
            client_id: args[:client_id],
            application_name: args[:application_name],
          ),
        ).to eq(true)
      end
    end
  end
end
