# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#new_bot" do
    it "serves a directly loaded HTML form for admins" do
      sign_in(admin)

      get "/admin/users/bots/new"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/html")
    end

    it "returns the site's bot form defaults as JSON for admins" do
      sign_in(admin)
      SiteSetting.default_trust_level = 2
      SiteSetting.full_name_requirement = "optional_at_signup"

      get "/admin/users/bots/new.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("default_trust_level" => 2, "name_required" => false)
    end

    it "reports when the site's full-name policy requires a name" do
      sign_in(admin)
      SiteSetting.full_name_requirement = "required_at_signup"

      get "/admin/users/bots/new.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["name_required"]).to eq(true)
    end

    it "rejects anonymous requests for JSON metadata" do
      get "/admin/users/bots/new.json"

      expect(response.status).to be_in([403, 404])
      expect(response.parsed_body).not_to have_key("default_trust_level")
    end

    it "rejects regular users and moderators requesting JSON metadata" do
      [user, moderator].each do |actor|
        sign_in(actor)

        get "/admin/users/bots/new.json"

        expect(response.status).to be_in([403, 404])
        expect(response.parsed_body).not_to have_key("default_trust_level")
      end
    end

    it "rejects anonymous visitors" do
      get "/admin/users/bots/new"

      expect(response.status).to be_in([403, 404])
    end

    it "rejects regular users" do
      sign_in(user)

      get "/admin/users/bots/new"

      expect(response.status).to be_in([403, 404])
    end

    it "rejects moderators" do
      sign_in(moderator)

      get "/admin/users/bots/new"

      expect(response.status).to be_in([403, 404])
    end
  end

  describe "#bot_username_suggestion" do
    it "suggests an available username from the name for admins" do
      Fabricate(:user, username: "release_helper")
      sign_in(admin)

      get "/admin/users/bots/username_suggestion.json", params: { name: "Release helper" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["username"]).to eq("Release_helper1")
    end

    it "rejects moderators" do
      sign_in(Fabricate(:moderator))

      get "/admin/users/bots/username_suggestion.json", params: { name: "Release helper" }

      expect(response.status).to eq(404)
    end
  end

  describe "#create_bot" do
    let(:bot_params) { { name: "Release helper", username: "release_helper", trust_level: 0 } }

    it "rejects anonymous requests without creating a user" do
      expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
        User,
        :count,
      )

      expect(response.status).to be_in([403, 404])
    end

    it "rejects regular users and moderators without creating a user" do
      [user, moderator].each do |actor|
        sign_in(actor)

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
          User,
          :count,
        )

        expect(response.status).to be_in([403, 404])
      end
    end

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "returns the created admin-user representation and a Location header" do
        SiteSetting.default_trust_level = 4

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.to change(
          User,
          :count,
        ).by(1)

        expect(response.status).to eq(201)
        bot = User.find_by!(username: bot_params[:username])
        expect(response.parsed_body.keys).to contain_exactly("user")
        expect(response.parsed_body["user"]).to include(
          "id" => bot.id,
          "username" => bot.username,
          "name" => bot.name,
          "trust_level" => 0,
          "admin" => false,
          "moderator" => false,
          "active" => true,
        )
        expect(response.headers["Location"]).to end_with("/admin/users/#{bot.id}/#{bot.username}")
      end

      it "accepts a JSON-encoded bot envelope through the real request parser" do
        post "/admin/users/bots.json", params: { bot: bot_params }, as: :json

        expect(response.status).to eq(201), response.body
        bot = User.find_by!(username: bot_params[:username])
        expect(response.parsed_body.dig("user", "id")).to eq(bot.id)
        expect(bot).to have_attributes(
          name: bot_params[:name],
          username: bot_params[:username],
          trust_level: bot_params[:trust_level],
          admin: false,
          moderator: false,
        )
      end

      it "rejects creation on an archived site without persisting an account" do
        SiteSetting.site_archived = true

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
          User,
          :count,
        )

        expect(response.status).to eq(503)
        expect(response.parsed_body["errors"]).to include(I18n.t("site_archived_error"))
      end

      it "returns normal validation errors for an invalid contract" do
        expect do
          post "/admin/users/bots.json", params: { bot: bot_params.merge(username: "") }
        end.not_to change(User, :count)

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_a(Array)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "rejects an omitted or blank required name without creating a user or audit entry" do
        SiteSetting.full_name_requirement = "required_at_signup"

        [{}, { name: nil }, { name: "" }, { name: " " }].each do |name_attributes|
          expect do
            post "/admin/users/bots.json",
                 params: {
                   bot: bot_params.except(:name).merge(name_attributes),
                 },
                 as: :json
          end.to not_change(User, :count).and(not_change(UserHistory, :count))

          expect(response.status).to eq(422), "Expected #{name_attributes.inspect} to be rejected"
          expect(response.parsed_body["errors"]).to be_present
        end
      end

      it "allows an omitted or blank name when full names are optional at signup" do
        SiteSetting.full_name_requirement = "optional_at_signup"

        [{}, { name: nil }, { name: "" }].each_with_index do |name_attributes, index|
          attributes =
            bot_params.except(:name).merge(name_attributes, username: "release_helper_#{index}")

          expect do
            post "/admin/users/bots.json", params: { bot: attributes }, as: :json
          end.to change(User, :count).by(1)

          expect(response.status).to eq(201), response.body
          expect(User.find_by!(username: attributes[:username]).name).to be_blank
        end
      end

      it "returns normal model errors and creates no duplicate account on retry" do
        post "/admin/users/bots.json", params: { bot: bot_params }
        expect(response.status).to eq(201)

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
          User,
          :count,
        )

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_a(Array)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "accepts explicit admin provisioning when public signup and local login are disabled" do
        SiteSetting.allow_new_registrations = false
        SiteSetting.enable_local_logins = false
        SiteSetting.must_approve_users = true
        SiteSetting.allowed_email_domains = "company.example"

        post "/admin/users/bots.json", params: { bot: bot_params }

        expect(response.status).to eq(201)
        expect(User.find_by!(username: bot_params[:username])).to have_attributes(
          active: true,
          approved: true,
        )
      end

      it "accepts explicit admin provisioning when DiscourseConnect is enforced" do
        SiteSetting.discourse_connect_url = "https://sso.example.com"
        SiteSetting.discourse_connect_secret = "a-long-discourse-connect-secret"
        SiteSetting.enable_discourse_connect = true

        post "/admin/users/bots.json", params: { bot: bot_params }

        expect(response.status).to eq(201)
      end

      it "logs the creating admin and bot in the staff audit history" do
        post "/admin/users/bots.json", params: { bot: bot_params }

        expect(response.status).to eq(201)
        expect(UserHistory.find_by!(action: UserHistory.actions[:create_bot])).to have_attributes(
          action: UserHistory.actions[:create_bot],
          acting_user_id: admin.id,
          target_user_id: response.parsed_body.dig("user", "id"),
        )
      end

      it "ignores prohibited bot attributes while creating an unprivileged account" do
        post "/admin/users/bots.json",
             params: {
               bot:
                 bot_params.merge(
                   admin: true,
                   moderator: true,
                   id: -9999,
                   active: false,
                   approved: false,
                   approved_by_id: user.id,
                   email: "forged@example.com",
                   password: "a-secret-password",
                   api_key: "a-secret-api-key",
                   custom_fields: {
                     privileged: true,
                   },
                   user_fields: {
                     "1" => "forged",
                   },
                 ),
             },
             as: :json

        expect(response.status).to eq(201)
        bot = User.find(response.parsed_body.dig("user", "id"))
        expect(bot).to have_attributes(
          username: bot_params[:username],
          admin: false,
          moderator: false,
          active: true,
          approved: true,
          approved_by_id: admin.id,
          password_hash: nil,
        )
        expect(bot.id).not_to eq(-9999)
        expect(bot.email).to match(/\A[0-9a-f]+@does-not-exist\.invalid\z/)
        expect(bot.api_keys).to be_empty
        expect(bot.custom_fields).to be_empty
        expect(bot.user_fields).to be_blank
      end

      it "requires a username inside the bot envelope" do
        expect do
          post "/admin/users/bots.json",
               params: {
                 bot: bot_params.except(:username),
                 username: "outside_bot",
               },
               as: :json
        end.to not_change(User, :count).and(not_change(UserHistory, :count))

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "ignores properties outside the bot envelope" do
        expect do
          post "/admin/users/bots.json",
               params: {
                 bot: bot_params,
                 id: -9999,
                 username: "outside_bot",
                 trust_level: 4,
                 admin: true,
                 moderator: true,
                 active: false,
                 approved: false,
                 email: "forged@example.com",
                 password: "a-secret-password",
                 api_key: "a-secret-api-key",
                 unexpected: "value",
               }
        end.to change(User, :count).by(1)

        expect(response.status).to eq(201)
        bot = User.find(response.parsed_body.dig("user", "id"))
        expect(bot).to have_attributes(
          username: bot_params[:username],
          trust_level: bot_params[:trust_level],
          admin: false,
          moderator: false,
          active: true,
          approved: true,
          password_hash: nil,
        )
        expect(bot.id).not_to eq(-9999)
        expect(bot.email).to match(/\A[0-9a-f]+@does-not-exist\.invalid\z/)
        expect(bot.api_keys).to be_empty
      end

      it "ignores a root user object in a JSON request" do
        expect do
          post "/admin/users/bots.json",
               params: {
                 bot: bot_params,
                 user: {
                   username: "outside_bot",
                   trust_level: 4,
                   admin: true,
                   moderator: true,
                   email: "forged@example.com",
                   password: "a-secret-password",
                   api_key: "a-secret-api-key",
                 },
               },
               as: :json
        end.to change(User, :count).by(1)

        expect(response.status).to eq(201)
        bot = User.find(response.parsed_body.dig("user", "id"))
        expect(bot).to have_attributes(
          username: bot_params[:username],
          trust_level: bot_params[:trust_level],
          admin: false,
          moderator: false,
          password_hash: nil,
        )
        expect(bot.email).to match(/\A[0-9a-f]+@does-not-exist\.invalid\z/)
        expect(bot.api_keys).to be_empty
      end

      it "requires an object-shaped bot envelope" do
        [nil, "release_helper", [bot_params]].each do |value|
          expect do
            post "/admin/users/bots.json", params: { bot: value }, as: :json
          end.not_to change(User, :count)

          expect(response.status).to eq(400)
        end
      end

      it "rejects missing and out-of-range trust levels without creating accounts" do
        [nil, -1, 5, ""].each do |value|
          expect do
            post "/admin/users/bots.json",
                 params: {
                   bot: bot_params.merge(trust_level: value),
                 },
                 as: :json
          end.not_to change(User, :count)

          expect(response.status).to eq(422),
          "Expected trust_level=#{value.inspect} to be rejected: #{response.body}"
          expect(response.parsed_body["errors"]).to be_present
        end
      end

      it "requires the normal CSRF token for creation" do
        ActionController::Base.allow_forgery_protection = true

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
          User,
          :count,
        )

        expect(response.status).to eq(403)
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it "continues to reject bot targets in existing privilege-grant endpoints" do
        post "/admin/users/bots.json", params: { bot: bot_params }
        expect(response.status).to eq(201)
        bot = User.find(response.parsed_body.dig("user", "id"))

        %w[grant_admin grant_moderation].each do |action|
          put "/admin/users/#{bot.id}/#{action}.json"

          expect(response.status).to eq(403)
          expect(bot.reload).to have_attributes(admin: false, moderator: false)
        end
        expect(AdminConfirmation.exists_for?(bot.id)).to eq(false)
      end

      context "with an API key" do
        let(:key_params) do
          {
            description: "Release key",
            scope_mode: "granular",
            scopes: [{ scope_id: "topics:write", topic_id: "1" }],
          }
        end

        it "creates a key for the bot and returns it once" do
          expect do
            post "/admin/users/bots.json", params: { bot: bot_params, key: key_params }, as: :json
          end.to change(User, :count).by(1).and change(ApiKey, :count).by(1)

          expect(response.status).to eq(201)
          bot = User.find(response.parsed_body.dig("user", "id"))
          api_key = ApiKey.last
          expect(api_key).to have_attributes(user: bot, created_by: admin, scope_mode: "granular")
          expect(response.parsed_body.dig("key", "key")).to be_present
          expect(ApiKey.with_key(response.parsed_body.dig("key", "key")).first).to eq(api_key)
        end

        it "returns no key when none was requested" do
          post "/admin/users/bots.json", params: { bot: bot_params }

          expect(response.status).to eq(201)
          expect(response.parsed_body).not_to have_key("key")
        end

        it "rejects an unknown scope without creating the bot" do
          key_params[:scopes] = [{ scope_id: "topics:explode" }]

          expect do
            post "/admin/users/bots.json", params: { bot: bot_params, key: key_params }
          end.to not_change(User, :count).and not_change(ApiKey, :count)
          expect(response.status).to eq(400)
        end

        it "rejects malformed scopes without creating the bot" do
          key_params[:scopes] = ["topics:write"]

          expect do
            post "/admin/users/bots.json", params: { bot: bot_params, key: key_params }, as: :json
          end.to not_change(User, :count).and not_change(ApiKey, :count)
          expect(response.status).to eq(400)
        end

        it "returns key validation errors without creating the bot" do
          key_params[:scopes] = []

          expect do
            post "/admin/users/bots.json", params: { bot: bot_params, key: key_params }, as: :json
          end.to not_change(User, :count).and not_change(ApiKey, :count)
          expect(response.status).to eq(422)
        end

        it "requires an object-shaped key" do
          expect do
            post "/admin/users/bots.json", params: { bot: bot_params, key: "a-key" }
          end.not_to change(User, :count)
          expect(response.status).to eq(400)
        end
      end
    end

    context "with rate limiting enabled for the admin" do
      before do
        sign_in(admin)
        RateLimiter.enable
      end

      after { RateLimiter.disable }

      it "allows ten attempts per minute, blocks the eleventh, and allows creation after reset" do
        freeze_time
        10.times do
          post "/admin/users/bots.json", params: { bot: bot_params.merge(username: "") }
          expect(response.status).to eq(422)
        end

        expect do post "/admin/users/bots.json", params: { bot: bot_params } end.not_to change(
          User,
          :count,
        )
        expect(response.status).to eq(429)

        freeze_time 61.seconds.from_now
        post "/admin/users/bots.json", params: { bot: bot_params }
        expect(response.status).to eq(201)
      end
    end
  end
end
