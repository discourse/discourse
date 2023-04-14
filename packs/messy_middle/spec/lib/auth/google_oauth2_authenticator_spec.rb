# frozen_string_literal: true

RSpec.describe Auth::GoogleOAuth2Authenticator do
  it "does not look up user unless email is verified" do
    # note, emails that come back from google via omniauth are always valid
    # this protects against future regressions

    authenticator = Auth::GoogleOAuth2Authenticator.new
    user = Fabricate(:user)

    hash = {
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        name: "John Doe",
        email: user.email,
      },
      extra: {
        raw_info: {
          email: user.email,
          email_verified: false,
          name: "John Doe",
        },
      },
    }

    result = authenticator.after_authenticate(hash)

    expect(result.user).to eq(nil)
  end

  describe "after_authenticate" do
    it "can authenticate and create a user record for already existing users" do
      authenticator = Auth::GoogleOAuth2Authenticator.new
      user = Fabricate(:user)

      hash = {
        provider: "google_oauth2",
        uid: "123456789",
        info: {
          name: "John Doe",
          email: user.email,
        },
        extra: {
          raw_info: {
            email: user.email,
            email_verified: true,
            name: "John Doe",
          },
        },
      }

      result = authenticator.after_authenticate(hash)

      expect(result.user.id).to eq(user.id)
    end

    it "can connect to a different existing user account" do
      authenticator = Auth::GoogleOAuth2Authenticator.new
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      UserAssociatedAccount.create!(
        provider_name: "google_oauth2",
        user_id: user1.id,
        provider_uid: 100,
      )

      hash = {
        provider: "google_oauth2",
        uid: "100",
        info: {
          name: "John Doe",
          email: user1.email,
        },
        extra: {
          raw_info: {
            email: user1.email,
            email_verified: true,
            name: "John Doe",
          },
        },
      }

      result = authenticator.after_authenticate(hash, existing_account: user2)

      expect(result.user.id).to eq(user2.id)
      expect(UserAssociatedAccount.exists?(user_id: user1.id)).to eq(false)
      expect(UserAssociatedAccount.exists?(user_id: user2.id)).to eq(true)
    end

    it "can create a proper result for non existing users" do
      hash = {
        provider: "google_oauth2",
        uid: "123456789",
        info: {
          first_name: "Jane",
          last_name: "Doe",
          name: "Jane Doe",
          email: "jane.doe@the.google.com",
        },
        extra: {
          raw_info: {
            email: "jane.doe@the.google.com",
            email_verified: true,
            name: "Jane Doe",
          },
        },
      }

      authenticator = described_class.new
      result = authenticator.after_authenticate(hash)

      expect(result.user).to eq(nil)
      expect(result.name).to eq("Jane Doe")
    end

    describe "provides groups" do
      before do
        SiteSetting.google_oauth2_hd = "domain.com"
        group1 = OmniAuth::AuthHash.new(id: "12345", name: "group1")
        group2 = OmniAuth::AuthHash.new(id: "67890", name: "group2")
        @groups = [group1, group2]
        @auth_hash =
          OmniAuth::AuthHash.new(
            provider: "google_oauth2",
            uid: "123456789",
            info: {
              first_name: "Jane",
              last_name: "Doe",
              name: "Jane Doe",
              email: "jane.doe@the.google.com",
            },
            extra: {
              raw_info: {
                email: "jane.doe@the.google.com",
                email_verified: true,
                name: "Jane Doe",
              },
            },
          )
      end

      context "when enabled" do
        let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }

        let(:group_response) do
          { groups: [{ id: "12345", name: "group1" }, { id: "67890", name: "group2" }] }
        end

        before do
          SiteSetting.google_oauth2_hd_groups_service_account_admin_email = "admin@example.com"
          SiteSetting.google_oauth2_hd_groups_service_account_json = {
            "private_key" => private_key.to_s,
            :"client_email" => "discourse-group-sync@example.iam.gserviceaccount.com",
          }.to_json
          SiteSetting.google_oauth2_hd_groups = true

          token = "abcde"

          stub_request(:post, "https://oauth2.googleapis.com/token").to_return do |request|
            jwt = Rack::Utils.parse_query(request.body)["assertion"]
            decoded_token = JWT.decode(jwt, private_key.public_key, true, { algorithm: "RS256" })
            {
              status: 200,
              body: { "access_token" => token, "type" => "bearer" }.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
            }
          rescue JWT::VerificationError
            { status: 403, body: "Invalid JWT" }
          end

          stub_request(
            :get,
            "https://admin.googleapis.com/admin/directory/v1/groups?userKey=#{@auth_hash.uid}",
          )
            .with(headers: { "Authorization" => "Bearer #{token}" })
            .to_return do
              {
                status: 200,
                body: group_response.to_json,
                headers: {
                  "Content-Type" => "application/json",
                },
              }
            end
        end

        it "adds associated groups" do
          result = described_class.new.after_authenticate(@auth_hash)
          expect(result.associated_groups).to eq(@groups)
        end

        it "handles a blank groups array" do
          group_response[:groups] = []
          result = described_class.new.after_authenticate(@auth_hash)
          expect(result.associated_groups).to eq([])
        end

        it "doesn't explode with invalid credentials" do
          SiteSetting.google_oauth2_hd_groups_service_account_json = {
            "private_key" => OpenSSL::PKey::RSA.generate(2048).to_s,
            :"client_email" => "discourse-group-sync@example.iam.gserviceaccount.com",
          }.to_json

          result = described_class.new.after_authenticate(@auth_hash)
          expect(result.associated_groups).to eq(nil)
        end
      end

      context "when disabled" do
        before { SiteSetting.google_oauth2_hd_groups = false }

        it "doesnt add associated groups" do
          result = described_class.new.after_authenticate(@auth_hash)
          expect(result.associated_groups).to eq(nil)
        end
      end
    end
  end

  describe "revoke" do
    fab!(:user) { Fabricate(:user) }
    let(:authenticator) { Auth::GoogleOAuth2Authenticator.new }

    it "raises exception if no entry for user" do
      expect { authenticator.revoke(user) }.to raise_error(Discourse::NotFound)
    end

    it "revokes correctly" do
      UserAssociatedAccount.create!(
        provider_name: "google_oauth2",
        user_id: user.id,
        provider_uid: 12_345,
      )
      expect(authenticator.can_revoke?).to eq(true)
      expect(authenticator.revoke(user)).to eq(true)
      expect(authenticator.description_for_user(user)).to eq("")
    end
  end
end
