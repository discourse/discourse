# frozen_string_literal: true

RSpec.describe InvitesController do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }

  describe "#show" do
    fab!(:invite)

    it "shows the accept invite page" do
      get "/invites/#{invite.invite_key}"
      expect(response.status).to eq(200)
      expect(response.body).to have_tag(
        :script,
        with: {
          "data-discourse-entrypoint" => "discourse",
        },
      )
      expect(response.body).not_to include(invite.email)
      expect(response.body).to_not include(
        I18n.t(
          "invite.not_found_template",
          site_name: SiteSetting.title,
          base_url: Discourse.base_url,
        ),
      )

      expect(response.body).to have_tag("div#data-preloaded") do |element|
        json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
        invite_info = JSON.parse(json["invite_info"])
        expect(invite_info["username"]).to eq("")
        expect(invite_info["email"]).to eq("i*****g@a***********e.ooo")
      end
    end

    context "when email data is present in authentication data" do
      let(:store) { ActionDispatch::Session::CookieStore.new({}) }
      let(:session_stub) do
        ActionDispatch::Request::Session.create(store, ActionDispatch::TestRequest.create, {})
      end

      before do
        session_stub[:authentication] = { email: invite.email }
        ActionDispatch::Request.any_instance.stubs(:session).returns(session_stub)
      end

      it "shows unobfuscated email" do
        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)
        expect(response.body).to_not have_tag(:body, with: { class: "no-ember" })
        expect(response.body).to include(invite.email)
        expect(response.body).not_to include("i*****g@a***********e.ooo")
      end
    end

    it "shows default user fields" do
      user_field = Fabricate(:user_field)
      staged_user = Fabricate(:user, staged: true, email: invite.email)
      staged_user.set_user_field(user_field.id, "some value")
      staged_user.save_custom_fields

      get "/invites/#{invite.invite_key}"
      expect(response.body).to have_tag("div#data-preloaded") do |element|
        json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
        invite_info = JSON.parse(json["invite_info"])
        expect(invite_info["username"]).to eq(staged_user.username)
        expect(invite_info["user_fields"][user_field.id.to_s]).to eq("some value")
      end
    end

    it "includes token validity boolean" do
      get "/invites/#{invite.invite_key}"
      expect(response.body).to have_tag("div#data-preloaded") do |element|
        json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
        invite_info = JSON.parse(json["invite_info"])
        expect(invite_info["email_verified_by_link"]).to eq(false)
      end

      get "/invites/#{invite.invite_key}?t=#{invite.email_token}"
      expect(response.body).to have_tag("div#data-preloaded") do |element|
        json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
        invite_info = JSON.parse(json["invite_info"])
        expect(invite_info["email_verified_by_link"]).to eq(true)
      end
    end

    describe "logged in user viewing an invite" do
      fab!(:group)

      before { sign_in(user) }

      it "shows the accept invite page when user's email matches the invite email" do
        invite.update_columns(email: user.email)

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)
        expect(response.body).to_not have_tag(:body, with: { class: "no-ember" })
        expect(response.body).not_to include(
          I18n.t(
            "invite.not_found_template",
            site_name: SiteSetting.title,
            base_url: Discourse.base_url,
          ),
        )

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["username"]).to eq(user.username)
          expect(invite_info["email"]).to eq(user.email)
          expect(invite_info["existing_user_id"]).to eq(user.id)
          expect(invite_info["existing_user_can_redeem"]).to eq(true)
        end
      end

      it "shows the accept invite page when user's email domain matches the domain an invite link is restricted to" do
        invite.update!(email: nil, domain: "discourse.org")
        user.update!(email: "someguy@discourse.org")

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)
        expect(response.body).to_not have_tag(:body, with: { class: "no-ember" })
        expect(response.body).not_to include(
          I18n.t(
            "invite.not_found_template",
            site_name: SiteSetting.title,
            base_url: Discourse.base_url,
          ),
        )

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["username"]).to eq(user.username)
          expect(invite_info["email"]).to eq(user.email)
          expect(invite_info["existing_user_id"]).to eq(user.id)
          expect(invite_info["existing_user_can_redeem"]).to eq(true)
        end
      end

      it "does not allow the user to accept the invite when their email domain does not match the domain of the invite" do
        user.update!(email: "someguy@discourse.com")
        invite.update!(email: nil, domain: "discourse.org")

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["existing_user_can_redeem"]).to eq(false)
          expect(invite_info["existing_user_can_redeem_error"]).to eq(
            I18n.t("invite.existing_user_cannot_redeem"),
          )
        end
      end

      it "does not allow the user to accept the invite when their email does not match the invite" do
        invite.update_columns(email: "notuseremail@discourse.org")

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["existing_user_can_redeem"]).to eq(false)
        end
      end

      it "does not allow the user to accept the invite when a multi-use invite link has already been redeemed by the user" do
        invite.update!(email: nil, max_redemptions_allowed: 10)
        expect(invite.redeem(redeeming_user: user)).not_to eq(nil)

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["existing_user_id"]).to eq(user.id)
          expect(invite_info["existing_user_can_redeem"]).to eq(false)
          expect(invite_info["existing_user_can_redeem_error"]).to eq(
            I18n.t("invite.existing_user_already_redemeed"),
          )
        end
      end

      it "allows the user to accept the invite when its an invite link that they have not redeemed" do
        invite.update!(email: nil, max_redemptions_allowed: 10)

        get "/invites/#{invite.invite_key}"
        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          invite_info = JSON.parse(json["invite_info"])
          expect(invite_info["existing_user_id"]).to eq(user.id)
          expect(invite_info["existing_user_can_redeem"]).to eq(true)
        end
      end
    end

    it "fails if invite does not exist" do
      get "/invites/missing"
      expect(response.status).to eq(200)

      expect(response.body).to have_tag(:body, with: { class: "no-ember" })
      expect(response.body).to include(I18n.t("invite.not_found", base_url: Discourse.base_url))
    end

    it "fails if invite expired" do
      invite.update(expires_at: 1.day.ago)

      get "/invites/#{invite.invite_key}"
      expect(response.status).to eq(200)

      expect(response.body).to have_tag(:body, with: { class: "no-ember" })
      expect(response.body).to include(I18n.t("invite.expired", base_url: Discourse.base_url))
    end

    it "stores the invite key in the secure session if invite exists" do
      get "/invites/#{invite.invite_key}"
      expect(response.status).to eq(200)
      invite_key = read_secure_session["invite-key"]
      expect(invite_key).to eq(invite.invite_key)
    end

    it "returns error if invite has already been redeemed" do
      expect(invite.redeem).not_to eq(nil)

      get "/invites/#{invite.invite_key}"
      expect(response.status).to eq(200)

      expect(response.body).to have_tag(:body, with: { class: "no-ember" })
      expect(response.body).to include(
        I18n.t(
          "invite.not_found_template",
          site_name: SiteSetting.title,
          base_url: Discourse.base_url,
        ),
      )

      invite.update!(email: nil) # convert to email invite

      get "/invites/#{invite.invite_key}"
      expect(response.status).to eq(200)

      expect(response.body).to have_tag(:body, with: { class: "no-ember" })
      expect(response.body).to include(
        I18n.t(
          "invite.not_found_template_link",
          site_name: SiteSetting.title,
          base_url: Discourse.base_url,
        ),
      )
    end
  end

  describe "#create" do
    it "requires to be logged in" do
      post "/invites.json", params: { email: "test@example.com" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user) }

      it "fails if you cannot invite to the forum" do
        sign_in(Fabricate(:user))

        post "/invites.json", params: { email: "test@example.com" }
        expect(response).to be_forbidden
      end
    end

    context "with invite to topic" do
      fab!(:topic)

      it "works" do
        sign_in(user)

        post "/invites.json",
             params: {
               email: "test@example.com",
               topic_id: topic.id,
               invite_to_topic: true,
             }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.first["args"].first["invite_to_topic"]).to be_truthy
      end

      it "fails when topic_id is invalid" do
        sign_in(user)

        post "/invites.json", params: { email: "test@example.com", topic_id: -9999 }
        expect(response.status).to eq(400)
      end

      context "when topic is private" do
        fab!(:group)

        fab!(:secured_category) do
          category = Fabricate(:category)
          category.permissions = { group.name => :full }
          category.save!
          category
        end

        fab!(:topic) { Fabricate(:topic, category: secured_category) }

        it "does not work and returns a list of required groups" do
          sign_in(admin)

          post "/invites.json", params: { email: "test@example.com", topic_id: topic.id }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to contain_exactly(
            I18n.t("invite.requires_groups", groups: group.name),
          )
        end

        it "does not work if user cannot edit groups" do
          group.add(user)
          sign_in(user)

          post "/invites.json", params: { email: "test@example.com", topic_id: topic.id }
          expect(response.status).to eq(403)
        end
      end
    end

    context "with invite to group" do
      fab!(:group)

      it "works for admins" do
        sign_in(admin)

        post "/invites.json", params: { email: "test@example.com", group_ids: [group.id] }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: "test@example.com").invited_groups.count).to eq(1)
      end

      it "works for group owners" do
        sign_in(user)
        group.add_owner(user)

        post "/invites.json", params: { email: "test@example.com", group_ids: [group.id] }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: "test@example.com").invited_groups.count).to eq(1)
      end

      it "works with multiple groups" do
        sign_in(admin)
        group2 = Fabricate(:group)

        post "/invites.json",
             params: {
               email: "test@example.com",
               group_names: "#{group.name},#{group2.name}",
             }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: "test@example.com").invited_groups.count).to eq(2)
      end

      it "fails for group members" do
        sign_in(user)
        group.add(user)

        post "/invites.json", params: { email: "test@example.com", group_ids: [group.id] }
        expect(response.status).to eq(403)
      end

      it "fails for other users" do
        sign_in(user)

        post "/invites.json", params: { email: "test@example.com", group_ids: [group.id] }
        expect(response.status).to eq(403)
      end

      it "fails to invite new user to a group-private topic" do
        sign_in(user)
        private_category = Fabricate(:private_category, group: group)
        group_private_topic = Fabricate(:topic, category: private_category)

        post "/invites.json",
             params: {
               email: "test@example.com",
               topic_id: group_private_topic.id,
             }
        expect(response.status).to eq(403)
      end
    end

    context "with email invite" do
      subject(:create_invite) { post "/invites.json", params: params }

      let(:params) { { email: email } }
      let(:email) { "test@example.com" }

      before { sign_in(user) }

      context "when doing successive calls" do
        let(:invite) { Invite.last }

        it "creates invite once and updates it after" do
          create_invite
          expect(response).to have_http_status :ok
          expect(Jobs::InviteEmail.jobs.size).to eq(1)

          create_invite
          expect(response).to have_http_status :ok
          expect(response.parsed_body["id"]).to eq(invite.id)
        end
      end

      context 'when "skip_email" parameter is provided' do
        before { params[:skip_email] = true }

        it "accepts the parameter" do
          create_invite
          expect(response).to have_http_status :ok
          expect(Jobs::InviteEmail.jobs.size).to eq(0)
        end
      end

      context "when validations fail" do
        let(:email) { "test@mailinator.com" }

        it "fails" do
          create_invite
          expect(response).to have_http_status :unprocessable_entity
          expect(response.parsed_body["errors"]).to be_present
        end
      end

      context "when email address is too long" do
        let(:email) { "a" * 495 + "@example.com" }

        it "fails" do
          create_invite
          expect(response).to have_http_status :unprocessable_entity
          expect(response.parsed_body["errors"]).to be_present
          error_message = response.parsed_body["errors"].first
          expect(error_message).to eq("Email is too long (maximum is 500 characters)")
        end
      end

      context "when providing an email belonging to an existing user" do
        let(:email) { user.email }

        before { SiteSetting.hide_email_address_taken = hide_email_address_taken }

        context 'when "hide_email_address_taken" setting is disabled' do
          let(:hide_email_address_taken) { false }

          it "returns an error" do
            create_invite
            expect(response).to have_http_status :unprocessable_entity
            expect(body).to match(/no need to invite/)
          end
        end

        context 'when "hide_email_address_taken" setting is enabled' do
          let(:hide_email_address_taken) { true }

          it "doesn’t inform the user" do
            create_invite
            expect(response).to have_http_status :unprocessable_entity
            expect(body).to match(/There was a problem with your request./)
          end
        end
      end
    end

    context "with domain invite" do
      it "works" do
        sign_in(admin)

        post "/invites.json", params: { domain: "example.com" }
        expect(response).to have_http_status :ok
      end

      it "fails when domain is invalid" do
        sign_in(admin)

        post "/invites.json", params: { domain: "example" }

        expect(response).to have_http_status :unprocessable_entity

        error_message = response.parsed_body["errors"].first
        expect(error_message).to eq(I18n.t("invite.domain_not_allowed_admin"))
      end

      it "fails when domain is too long" do
        sign_in(admin)

        post "/invites.json", params: { domain: "a" * 500 + ".ca" }
        expect(response).to have_http_status :unprocessable_entity

        error_message = response.parsed_body["errors"].first
        expect(error_message).to eq("Domain is too long (maximum is 500 characters)")
      end

      it "fails when custom message is too long" do
        sign_in(admin)

        post "/invites.json", params: { custom_message: "b" * 1001, domain: "example.com" }
        expect(response).to have_http_status :unprocessable_entity

        error_message = response.parsed_body["errors"].first
        expect(error_message).to eq("Custom message is too long (maximum is 1000 characters)")
      end
    end

    context "with link invite" do
      it "works" do
        sign_in(admin)

        post "/invites.json"
        expect(response.status).to eq(200)
        expect(Invite.last.email).to eq(nil)
        expect(Invite.last.invited_by).to eq(admin)
        expect(Invite.last.max_redemptions_allowed).to eq(1)
      end

      it "fails if over invite_link_max_redemptions_limit" do
        sign_in(admin)

        post "/invites.json",
             params: {
               max_redemptions_allowed: SiteSetting.invite_link_max_redemptions_limit - 1,
             }
        expect(response.status).to eq(200)

        post "/invites.json",
             params: {
               max_redemptions_allowed: SiteSetting.invite_link_max_redemptions_limit + 1,
             }
        expect(response.status).to eq(422)
      end

      it "fails if over invite_link_max_redemptions_limit_users" do
        sign_in(user)

        post "/invites.json",
             params: {
               max_redemptions_allowed: SiteSetting.invite_link_max_redemptions_limit_users - 1,
             }
        expect(response.status).to eq(200)

        post "/invites.json",
             params: {
               max_redemptions_allowed: SiteSetting.invite_link_max_redemptions_limit_users + 1,
             }
        expect(response.status).to eq(422)
      end
    end
  end

  describe "#create-multiple" do
    it "fails if you are not admin" do
      sign_in(Fabricate(:user))
      post "/invites/create-multiple.json",
           params: {
             email: %w[test@example.com test1@example.com bademail],
           }
      expect(response.status).to eq(403)
    end

    it "creates multiple invites for multiple emails" do
      sign_in(admin)
      post "/invites/create-multiple.json",
           params: {
             email: %w[test@example.com test1@example.com bademail],
           }
      expect(response.status).to eq(200)
      json = JSON(response.body)
      expect(json["failed_invitations"].length).to eq(1)
      expect(json["successful_invitations"].length).to eq(2)
    end

    it "creates many invite codes with one request" do #change to
      sign_in(admin)
      num_emails = 5 # increase manually for load testing
      post "/invites/create-multiple.json",
           params: {
             email: 1.upto(num_emails).map { |i| "test#{i}@example.com" },
             #email: %w[test+1@example.com test1@example.com]
           }
      expect(response.status).to eq(200)
      json = JSON(response.body)
      expect(json["failed_invitations"].length).to eq(0)
      expect(json["successful_invitations"].length).to eq(num_emails)
    end

    context "with invite to topic" do
      fab!(:topic)

      it "works" do
        sign_in(admin)

        post "/invites/create-multiple.json",
             params: {
               email: ["test@example.com"],
               topic_id: topic.id,
               invite_to_topic: true,
             }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.first["args"].first["invite_to_topic"]).to be_truthy
      end

      it "fails when topic_id is invalid" do
        sign_in(admin)

        post "/invites/create-multiple.json",
             params: {
               email: ["test@example.com"],
               topic_id: -9999,
             }
        expect(response.status).to eq(400)
      end
    end

    context "with invite to group" do
      fab!(:group)

      it "works for admins" do
        sign_in(admin)

        post "/invites/create-multiple.json",
             params: {
               email: ["test@example.com"],
               group_ids: [group.id],
             }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: "test@example.com").invited_groups.count).to eq(1)
      end

      it "works with multiple groups" do
        sign_in(admin)
        group2 = Fabricate(:group)

        post "/invites/create-multiple.json",
             params: {
               email: ["test@example.com"],
               group_names: "#{group.name},#{group2.name}",
             }
        expect(response.status).to eq(200)
        expect(Invite.find_by(email: "test@example.com").invited_groups.count).to eq(2)
      end
    end

    context "with email invite" do
      subject(:create_multiple_invites) { post "/invites/create-multiple.json", params: params }

      let(:params) { { email: [email] } }
      let(:email) { "test@example.com" }

      before { sign_in(admin) }

      context "when doing successive calls" do
        let(:invite) { Invite.last }

        it "creates invite once and updates it after" do
          create_multiple_invites
          expect(response).to have_http_status :ok
          expect(Jobs::InviteEmail.jobs.size).to eq(1)

          create_multiple_invites
          expect(response).to have_http_status :ok
          expect(response.parsed_body["successful_invitations"][0]["invite"]["id"]).to eq(invite.id)
        end
      end

      context 'when "skip_email" parameter is provided' do
        before { params[:skip_email] = true }

        it "accepts the parameter" do
          create_multiple_invites
          expect(response).to have_http_status :ok
          expect(Jobs::InviteEmail.jobs.size).to eq(0)
        end
      end
    end

    it "fails if asked to generate too many invites at once" do
      SiteSetting.max_api_invites = 3
      sign_in(admin)
      post "/invites/create-multiple.json",
           params: {
             email: %w[
               mail1@mailinator.com
               mail2@mailinator.com
               mail3@mailinator.com
               mail4@mailinator.com
             ],
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"][0]).to eq(
        I18n.t("invite.max_invite_emails_limit_exceeded", max: SiteSetting.max_api_invites),
      )
    end
  end

  describe "#retrieve" do
    it "requires to be logged in" do
      get "/invites/retrieve.json", params: { email: "test@example.com" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user) }

      fab!(:invite) { Fabricate(:invite, invited_by: user, email: "test@example.com") }

      it "raises an error when the email is missing" do
        get "/invites/retrieve.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the email cannot be found" do
        get "/invites/retrieve.json", params: { email: "test2@example.com" }
        expect(response.status).to eq(400)
      end

      it "can retrieve the invite" do
        get "/invites/retrieve.json", params: { email: "test@example.com" }
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#update" do
    fab!(:invite) { Fabricate(:invite, invited_by: admin, email: "test@example.com") }

    it "requires to be logged in" do
      put "/invites/#{invite.id}", params: { email: "test2@example.com" }
      expect(response.status).to eq(400)
    end

    context "while logged in" do
      before { sign_in(admin) }

      it "resends invite email if updating email address" do
        put "/invites/#{invite.id}", params: { email: "test2@example.com" }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.size).to eq(1)
      end

      it "does not resend invite email if skip_email if updating email address" do
        put "/invites/#{invite.id}", params: { email: "test2@example.com", skip_email: true }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.size).to eq(0)
      end

      it "does not resend invite email when updating other fields" do
        put "/invites/#{invite.id}", params: { custom_message: "new message" }
        expect(response.status).to eq(200)
        expect(invite.reload.custom_message).to eq("new message")
        expect(Jobs::InviteEmail.jobs.size).to eq(0)
      end

      it "cannot create duplicated invites" do
        Fabricate(:invite, invited_by: admin, email: "test2@example.com")

        put "/invites/#{invite.id}.json", params: { email: "test2@example.com" }
        expect(response.status).to eq(409)
      end

      describe "rate limiting" do
        before { RateLimiter.enable }

        use_redis_snapshotting

        it "can send invite email" do
          sign_in(user)

          invite = Fabricate(:invite, invited_by: user, email: "test@example.com")

          expect { put "/invites/#{invite.id}", params: { send_email: true } }.to change {
            RateLimiter.new(user, "resend-invite-per-hour", 10, 1.hour).remaining
          }.by(-1)
          expect(response.status).to eq(200)
          expect(Jobs::InviteEmail.jobs.size).to eq(1)
        end
      end

      context "when providing an email belonging to an existing user" do
        subject(:update_invite) { put "/invites/#{invite.id}.json", params: { email: admin.email } }

        before { SiteSetting.hide_email_address_taken = hide_email_address_taken }

        context "when 'hide_email_address_taken' setting is disabled" do
          let(:hide_email_address_taken) { false }

          it "returns an error" do
            update_invite
            expect(response).to have_http_status :unprocessable_entity
            expect(body).to match(/no need to invite/)
          end
        end

        context "when 'hide_email_address_taken' setting is enabled" do
          let(:hide_email_address_taken) { true }

          it "doesn't inform the user" do
            update_invite
            expect(response).to have_http_status :unprocessable_entity
            expect(body).to match(/There was a problem with your request./)
          end
        end
      end
    end
  end

  describe "#destroy" do
    it "requires to be logged in" do
      delete "/invites.json", params: { email: "test@example.com" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      fab!(:invite) { Fabricate(:invite, invited_by: user) }

      before { sign_in(user) }

      it "raises an error when id is missing" do
        delete "/invites.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when invite does not exist" do
        delete "/invites.json", params: { id: 848 }
        expect(response.status).to eq(400)
      end

      it "raises an error when invite is not created by user" do
        another_invite = Fabricate(:invite, email: "test2@example.com")

        delete "/invites.json", params: { id: another_invite.id }
        expect(response.status).to eq(400)
      end

      it "destroys the invite" do
        delete "/invites.json", params: { id: invite.id }
        expect(response.status).to eq(200)
        expect(invite.reload.trashed?).to be_truthy
      end
    end
  end

  describe "#perform_accept_invitation" do
    context "with an invalid invite" do
      it "redirects to the root" do
        put "/invites/show/doesntexist.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.not_found_json"))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context "with a deleted invite" do
      fab!(:invite)

      before { invite.trash! }

      it "redirects to the root" do
        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.not_found_json"))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context "with an expired invite" do
      fab!(:invite) { Fabricate(:invite, expires_at: 1.day.ago) }

      it "response is not successful" do
        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.not_found_json"))
        expect(session[:current_user_id]).to be_blank
      end
    end

    context "with an email invite" do
      let(:topic) { Fabricate(:topic) }
      let(:invite) { Invite.generate(topic.user, email: "iceking@adventuretime.ooo", topic: topic) }

      it "redeems the invite" do
        put "/invites/show/#{invite.invite_key}.json"
        expect(invite.reload.redeemed?).to be_truthy
      end

      it "logs in the user" do
        events =
          DiscourseEvent.track_events do
            put "/invites/show/#{invite.invite_key}.json",
                params: {
                  email_token: invite.email_token,
                }
          end

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in,
          :user_first_logged_in,
        )
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to eq(invite.invited_users.first.user_id)
        expect(invite.reload.redeemed?).to be_truthy
        user = User.find(invite.invited_users.first.user_id)
        expect(user.ip_address).to be_present
        expect(user.registration_ip_address).to be_present
      end

      it "redirects to the first topic the user was invited to" do
        put "/invites/show/#{invite.invite_key}.json", params: { email_token: invite.email_token }
        expect(response.status).to eq(200)
        expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
        expect(
          Notification.where(
            notification_type: Notification.types[:invited_to_topic],
            topic: topic,
          ).count,
        ).to eq(1)
      end

      it "sets the timezone of the user in user_options" do
        put "/invites/show/#{invite.invite_key}.json", params: { timezone: "Australia/Melbourne" }
        expect(response.status).to eq(200)
        invite.reload
        user = User.find(invite.invited_users.first.user_id)
        expect(user.user_option.timezone).to eq("Australia/Melbourne")
      end

      it "does not log in the user if there are validation errors" do
        put "/invites/show/#{invite.invite_key}.json", params: { password: "password" }

        expect(response.status).to eq(412)
        expect(session[:current_user_id]).to eq(nil)
      end

      it "does not log in the user if they were not approved" do
        SiteSetting.must_approve_users = true

        put "/invites/show/#{invite.invite_key}.json",
            params: {
              password: SecureRandom.hex,
              email_token: invite.email_token,
            }

        expect(session[:current_user_id]).to eq(nil)
        expect(response.parsed_body["message"]).to eq(I18n.t("activation.approval_required"))
      end

      it "does not log in the user if they were not activated" do
        put "/invites/show/#{invite.invite_key}.json", params: { password: SecureRandom.hex }

        expect(session[:current_user_id]).to eq(nil)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.confirm_email"))
      end

      it "fails when local login is disabled and no external auth is configured" do
        SiteSetting.enable_local_logins = false

        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(404)
      end

      it "fails when discourse connect is enabled" do
        SiteSetting.discourse_connect_url = "https://example.com/sso"
        SiteSetting.enable_discourse_connect = true

        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(404)
      end

      context "with OmniAuth provider" do
        fab!(:authenticated_email) { "test@example.com" }

        before do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
            provider: "google_oauth2",
            uid: "12345",
            info: OmniAuth::AuthHash::InfoHash.new(email: authenticated_email, name: "First Last"),
            extra: {
              raw_info:
                OmniAuth::AuthHash.new(
                  email_verified: true,
                  email: authenticated_email,
                  family_name: "Last",
                  given_name: "First",
                  gender: "male",
                  name: "First Last",
                ),
            },
          )

          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
          SiteSetting.enable_google_oauth2_logins = true

          get "/auth/google_oauth2/callback.json"
          expect(response.status).to eq(302)
        end

        after do
          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[
            :google_oauth2
          ] = nil
          OmniAuth.config.test_mode = false
        end

        it "should associate the invited user with authenticator records" do
          SiteSetting.auth_overrides_name = true
          invite.update!(email: authenticated_email)

          expect {
            put "/invites/show/#{invite.invite_key}.json", params: { name: "somename" }
          }.to change { User.with_email(authenticated_email).exists? }.to(true)
          expect(response.status).to eq(200)

          user = User.find_by_email(authenticated_email)
          expect(user.name).to eq("First Last")
          expect(user.user_associated_accounts.first.provider_name).to eq("google_oauth2")
        end

        it "returns the right response even if local logins has been disabled" do
          SiteSetting.enable_local_logins = false
          invite.update!(email: authenticated_email)

          put "/invites/show/#{invite.invite_key}.json"
          expect(response.status).to eq(200)
        end

        it "returns the right response if authenticated email does not match invite email" do
          put "/invites/show/#{invite.invite_key}.json"
          expect(response.status).to eq(412)
        end
      end

      describe ".post_process_invite" do
        it "sends a welcome message if set" do
          SiteSetting.send_welcome_message = true
          user.send_welcome_message = true
          put "/invites/show/#{invite.invite_key}.json"
          expect(response.status).to eq(200)

          expect(Jobs::SendSystemMessage.jobs.size).to eq(1)
        end

        it "refreshes automatic groups if staff" do
          topic.user.grant_admin!
          invite.update!(moderator: true)

          put "/invites/show/#{invite.invite_key}.json"
          expect(response.status).to eq(200)

          expect(invite.invited_users.first.user.groups.pluck(:name)).to contain_exactly(
            "moderators",
            "staff",
          )
        end

        context "without password" do
          it "sends password reset email" do
            put "/invites/show/#{invite.invite_key}.json"
            expect(response.status).to eq(200)

            expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(1)
            expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
          end
        end

        context "with password" do
          context "when user was invited via email" do
            before { invite.update_column(:emailed_status, Invite.emailed_status_types[:pending]) }

            it "does not send an activation email and activates the user" do
              expect do
                put "/invites/show/#{invite.invite_key}.json",
                    params: {
                      password: "verystrongpassword",
                      email_token: invite.email_token,
                    }
              end.to change { UserAuthToken.count }.by(1)

              expect(response.status).to eq(200)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)

              invited_user = User.find_by_email(invite.email)
              expect(invited_user.active).to eq(true)
              expect(invited_user.email_confirmed?).to eq(true)
            end

            it "does not activate user if email token is missing" do
              expect do
                put "/invites/show/#{invite.invite_key}.json",
                    params: {
                      password: "verystrongpassword",
                    }
              end.not_to change { UserAuthToken.count }

              expect(response.status).to eq(200)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)

              invited_user = User.find_by_email(invite.email)
              expect(invited_user.active).to eq(false)
              expect(invited_user.email_confirmed?).to eq(false)
            end
          end

          context "when user was invited via link" do
            before do
              invite.update_column(:emailed_status, Invite.emailed_status_types[:not_required])
            end

            it "sends an activation email and does not activate the user" do
              expect do
                put "/invites/show/#{invite.invite_key}.json",
                    params: {
                      password: "verystrongpassword",
                    }
              end.not_to change { UserAuthToken.count }

              expect(response.status).to eq(200)
              expect(response.parsed_body["message"]).to eq(I18n.t("invite.confirm_email"))

              invited_user = User.find_by_email(invite.email)
              expect(invited_user.active).to eq(false)
              expect(invited_user.email_confirmed?).to eq(false)

              expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
              expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)

              tokens = EmailToken.where(user_id: invited_user.id, confirmed: false, expired: false)
              expect(tokens.size).to eq(1)

              job_args = Jobs::CriticalUserEmail.jobs.first["args"].first
              expect(job_args["type"]).to eq("signup")
              expect(job_args["user_id"]).to eq(invited_user.id)
              expect(EmailToken.hash_token(job_args["email_token"])).to eq(tokens.first.token_hash)
            end
          end
        end
      end
    end

    context "with a domain invite" do
      fab!(:invite) do
        Fabricate(
          :invite,
          email: nil,
          emailed_status: Invite.emailed_status_types[:not_required],
          domain: "example.com",
        )
      end

      it "creates an user if email matches domain" do
        expect {
          put "/invites/show/#{invite.invite_key}.json",
              params: {
                email: "test@example.com",
                password: "verystrongpassword",
              }
        }.to change { User.count }

        expect(response.status).to eq(200)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.confirm_email"))
        expect(invite.reload.redemption_count).to eq(1)

        invited_user = User.find_by_email("test@example.com")
        expect(invited_user).to be_present
      end

      it "does not create an user if email does not match domain" do
        expect {
          put "/invites/show/#{invite.invite_key}.json",
              params: {
                email: "test@example2.com",
                password: "verystrongpassword",
              }
        }.not_to change { User.count }

        expect(response.status).to eq(412)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.domain_not_allowed"))
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "with an invite link" do
      fab!(:invite) do
        Fabricate(:invite, email: nil, emailed_status: Invite.emailed_status_types[:not_required])
      end

      it "does not create multiple users for a single use invite" do
        user_count = User.count

        2
          .times
          .map do
            Thread.new do
              put "/invites/show/#{invite.invite_key}.json",
                  params: {
                    email: "test@example.com",
                    password: "verystrongpassword",
                  }
            end
          end
          .each(&:join)

        expect(invite.reload.max_redemptions_allowed).to eq(1)
        expect(invite.reload.redemption_count).to eq(1)
        expect(User.count).to eq(user_count + 1)
      end

      it "sends an activation email and does not activate the user" do
        expect {
          put "/invites/show/#{invite.invite_key}.json",
              params: {
                email: "test@example.com",
                password: "verystrongpassword",
              }
        }.not_to change { UserAuthToken.count }

        expect(response.status).to eq(200)
        expect(response.parsed_body["message"]).to eq(I18n.t("invite.confirm_email"))
        expect(invite.reload.redemption_count).to eq(1)

        invited_user = User.find_by_email("test@example.com")
        expect(invited_user.active).to eq(false)
        expect(invited_user.email_confirmed?).to eq(false)

        expect(Jobs::InvitePasswordInstructionsEmail.jobs.size).to eq(0)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)

        tokens = EmailToken.where(user_id: invited_user.id, confirmed: false, expired: false)
        expect(tokens.size).to eq(1)

        job_args = Jobs::CriticalUserEmail.jobs.first["args"].first
        expect(job_args["type"]).to eq("signup")
        expect(job_args["user_id"]).to eq(invited_user.id)
        expect(EmailToken.hash_token(job_args["email_token"])).to eq(tokens.first.token_hash)
      end

      it "does not automatically log in the user if their email matches an existing user's and shows an error" do
        Fabricate(:user, email: "test@example.com")
        put "/invites/show/#{invite.invite_key}.json",
            params: {
              email: "test@example.com",
              password: "verystrongpassword",
            }
        expect(session[:current_user_id]).to be_blank
        expect(response.status).to eq(412)
        expect(response.parsed_body["message"]).to include("Primary email has already been taken")
        expect(invite.reload.redemption_count).to eq(0)
      end

      it "does not automatically log in the user if their email matches an existing admin's and shows an error" do
        Fabricate(:admin, email: "test@example.com")
        put "/invites/show/#{invite.invite_key}.json",
            params: {
              email: "test@example.com",
              password: "verystrongpassword",
            }
        expect(session[:current_user_id]).to be_blank
        expect(response.status).to eq(412)
        expect(response.parsed_body["message"]).to include("Primary email has already been taken")
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when new registrations are disabled" do
      fab!(:topic)
      fab!(:invite) { Invite.generate(topic.user, email: "test@example.com", topic: topic) }

      before { SiteSetting.allow_new_registrations = false }

      it "does not redeem the invite" do
        put "/invites/show/#{invite.invite_key}.json"
        expect(response.status).to eq(200)
        expect(invite.reload.invited_users).to be_blank
        expect(invite.redeemed?).to be_falsey
        expect(response.body).to include(I18n.t("login.new_registrations_disabled"))
      end
    end

    context "when user is already logged in" do
      before { sign_in(user) }

      context "for an email invite" do
        fab!(:invite) { Fabricate(:invite, email: "test@example.com") }
        fab!(:user) { Fabricate(:user, email: "test@example.com") }
        fab!(:group)

        it "redeems the invitation and creates the invite accepted notification" do
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
          invite.reload
          expect(invite.invited_users.first.user).to eq(user)
          expect(invite.redeemed?).to be_truthy
          expect(
            Notification.exists?(
              user: invite.invited_by,
              notification_type: Notification.types[:invitee_accepted],
            ),
          ).to eq(true)
        end

        it "redirects to the first topic the user was invited to and creates the topic notification" do
          topic = Fabricate(:topic)
          TopicInvite.create!(invite: invite, topic: topic)
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
          expect(
            Notification.where(
              notification_type: Notification.types[:invited_to_topic],
              topic: topic,
            ).count,
          ).to eq(1)
        end

        it "adds the user to the private topic" do
          topic = Fabricate(:private_message_topic)
          TopicInvite.create!(invite: invite, topic: topic)
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
          expect(TopicAllowedUser.exists?(user: user, topic: topic)).to eq(true)
        end

        it "adds the user to the groups specified on the invite and allows them to access the secure topic" do
          group.add_owner(invite.invited_by)
          secured_category = Fabricate(:category)
          secured_category.permissions = { group.name => :full }
          secured_category.save!

          topic = Fabricate(:topic, category: secured_category)
          TopicInvite.create!(invite: invite, topic: topic)
          InvitedGroup.create!(invite: invite, group: group)

          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
          expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
          invite.reload
          expect(invite.redeemed?).to be_truthy
          expect(user.reload.groups).to include(group)
          expect(
            Notification.where(
              notification_type: Notification.types[:invited_to_topic],
              topic: topic,
            ).count,
          ).to eq(1)
        end

        it "does not try to log in the user automatically" do
          expect do
            put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          end.not_to change { UserAuthToken.count }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
        end

        it "errors if the user's email doesn't match the invite email" do
          user.update!(email: "blah@test.com")
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(412)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.not_matching_email"))
        end

        it "errors if the user's email domain doesn't match the invite domain" do
          user.update!(email: "blah@test.com")
          invite.update!(email: nil, domain: "example.com")
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(412)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.domain_not_allowed"))
        end
      end

      context "for an invite link" do
        fab!(:invite) { Fabricate(:invite, email: nil) }
        fab!(:user) { Fabricate(:user, email: "test@example.com") }
        fab!(:group)

        it "redeems the invitation and creates the invite accepted notification" do
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
          invite.reload
          expect(invite.invited_users.first.user).to eq(user)
          expect(invite.redeemed?).to be_truthy
          expect(
            Notification.exists?(
              user: invite.invited_by,
              notification_type: Notification.types[:invitee_accepted],
            ),
          ).to eq(true)
        end

        it "redirects to the first topic the user was invited to and creates the topic notification" do
          topic = Fabricate(:topic)
          TopicInvite.create!(invite: invite, topic: topic)
          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
          expect(
            Notification.where(
              notification_type: Notification.types[:invited_to_topic],
              topic: topic,
            ).count,
          ).to eq(1)
        end

        it "adds the user to the groups specified on the invite and allows them to access the secure topic" do
          group.add_owner(invite.invited_by)
          secured_category = Fabricate(:category)
          secured_category.permissions = { group.name => :full }
          secured_category.save!

          topic = Fabricate(:topic, category: secured_category)
          TopicInvite.create!(invite: invite, topic: topic)
          InvitedGroup.create!(invite: invite, group: group)

          put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
          expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
          invite.reload
          expect(invite.redeemed?).to be_truthy
          expect(user.reload.groups).to include(group)
          expect(
            Notification.where(
              notification_type: Notification.types[:invited_to_topic],
              topic: topic,
            ).count,
          ).to eq(1)
        end

        it "does not try to log in the user automatically" do
          expect do
            put "/invites/show/#{invite.invite_key}.json", params: { id: invite.invite_key }
          end.not_to change { UserAuthToken.count }
          expect(response.status).to eq(200)
          expect(response.parsed_body["message"]).to eq(I18n.t("invite.existing_user_success"))
        end
      end
    end

    context "with topic invites" do
      fab!(:invite) { Fabricate(:invite, email: "test@example.com") }

      fab!(:secured_category) do
        secured_category = Fabricate(:category)
        secured_category.permissions = { staff: :full }
        secured_category.save!
        secured_category
      end

      it "redirects user to topic if activated" do
        topic = Fabricate(:topic)
        TopicInvite.create!(invite: invite, topic: topic)

        put "/invites/show/#{invite.invite_key}.json", params: { email_token: invite.email_token }
        expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
        expect(
          Notification.where(
            notification_type: Notification.types[:invited_to_topic],
            topic: topic,
          ).count,
        ).to eq(1)
      end

      it "sets destination_url cookie if user is not activated" do
        topic = Fabricate(:topic)
        TopicInvite.create!(invite: invite, topic: topic)

        put "/invites/show/#{invite.invite_key}.json"
        expect(cookies["destination_url"]).to eq(topic.relative_url)
        expect(
          Notification.where(
            notification_type: Notification.types[:invited_to_topic],
            topic: topic,
          ).count,
        ).to eq(1)
      end

      it "does not redirect user if they cannot see topic" do
        topic = Fabricate(:topic, category: secured_category)
        TopicInvite.create!(invite: invite, topic: topic)

        put "/invites/show/#{invite.invite_key}.json", params: { email_token: invite.email_token }
        expect(response.parsed_body["redirect_to"]).to eq("/")
        expect(
          Notification.where(
            notification_type: Notification.types[:invited_to_topic],
            topic: topic,
          ).count,
        ).to eq(0)
      end
    end

    context "with staged user" do
      fab!(:invite)
      fab!(:staged_user) { Fabricate(:user, staged: true, email: invite.email) }

      it "can keep the old username" do
        old_username = staged_user.username

        put "/invites/show/#{invite.invite_key}.json",
            params: {
              username: staged_user.username,
              password: "Password123456",
              email_token: invite.email_token,
            }

        expect(response.status).to eq(200)
        expect(invite.reload.redeemed?).to be_truthy
        user = invite.invited_users.first.user
        expect(user.username).to eq(old_username)
      end

      it "can change the username" do
        put "/invites/show/#{invite.invite_key}.json",
            params: {
              username: "new_username",
              password: "Password123456",
              email_token: invite.email_token,
            }

        expect(response.status).to eq(200)
        expect(invite.reload.redeemed?).to be_truthy
        user = invite.invited_users.first.user
        expect(user.username).to eq("new_username")
      end
    end
  end

  describe "#destroy_all_expired" do
    it "removes all expired invites sent by a user" do
      SiteSetting.invite_expiry_days = 1

      user = Fabricate(:admin)
      invite_1 = Fabricate(:invite, invited_by: user)
      invite_2 = Fabricate(:invite, invited_by: user)
      expired_invite = Fabricate(:invite, invited_by: user)
      expired_invite.update!(expires_at: 2.days.ago)

      sign_in(user)
      post "/invites/destroy-all-expired"

      expect(response.status).to eq(200)
      expect(invite_1.reload.deleted_at).to eq(nil)
      expect(invite_2.reload.deleted_at).to eq(nil)
      expect(expired_invite.reload.deleted_at).to be_present
    end
  end

  describe "#resend_invite" do
    it "requires to be logged in" do
      post "/invites/reinvite.json", params: { email: "first_name@example.com" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      fab!(:user) { sign_in(Fabricate(:user)) }
      fab!(:invite) { Fabricate(:invite, invited_by: user) }
      fab!(:another_invite) { Fabricate(:invite, email: "last_name@example.com") }

      it "raises an error when the email is missing" do
        post "/invites/reinvite.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the email cannot be found" do
        post "/invites/reinvite.json", params: { email: "first_name@example.com" }
        expect(response.status).to eq(400)
      end

      it "raises an error when the invite is not yours" do
        post "/invites/reinvite.json", params: { email: another_invite.email }
        expect(response.status).to eq(400)
      end

      it "resends the invite" do
        post "/invites/reinvite.json", params: { email: invite.email }
        expect(response.status).to eq(200)
        expect(Jobs::InviteEmail.jobs.size).to eq(1)
      end
    end
  end

  describe "#resend_all_invites" do
    let(:admin) { Fabricate(:admin) }

    before do
      SiteSetting.invite_expiry_days = 30
      RateLimiter.enable
    end

    use_redis_snapshotting

    it "resends all non-redeemed invites by a user" do
      freeze_time

      new_invite = Fabricate(:invite, invited_by: admin)
      expired_invite = Fabricate(:invite, invited_by: admin)
      expired_invite.update!(expires_at: 2.days.ago)
      redeemed_invite = Fabricate(:invite, invited_by: admin)
      Fabricate(:invited_user, invite: redeemed_invite, user: Fabricate(:user))
      redeemed_invite.update!(expires_at: 5.days.ago)

      sign_in(admin)
      post "/invites/reinvite-all"

      expect(response.status).to eq(200)
      expect(new_invite.reload.expires_at).to eq_time(30.days.from_now)
      expect(expired_invite.reload.expires_at).to eq_time(2.days.ago)
      expect(redeemed_invite.reload.expires_at).to eq_time(5.days.ago)
    end

    it "errors if admins try to exceed limit of one bulk invite per day" do
      sign_in(admin)
      start = Time.now

      freeze_time(start)
      post "/invites/reinvite-all"
      expect(response.parsed_body["errors"]).to_not be_present

      freeze_time(start + 10.minutes)
      post "/invites/reinvite-all"
      expect(response.parsed_body["errors"][0]).to eq(I18n.t("rate_limiter.slow_down"))
    end
  end

  describe "#upload_csv" do
    it "requires to be logged in" do
      post "/invites/upload_csv.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }
      let(:file) { Rack::Test::UploadedFile.new(File.open(csv_file)) }

      let(:csv_file_with_headers) do
        File.new("#{Rails.root}/spec/fixtures/csv/discourse_headers.csv")
      end
      let(:file_with_headers) { Rack::Test::UploadedFile.new(File.open(csv_file_with_headers)) }
      let(:csv_file_with_locales) do
        File.new("#{Rails.root}/spec/fixtures/csv/invites_with_locales.csv")
      end
      let(:file_with_locales) { Rack::Test::UploadedFile.new(File.open(csv_file_with_locales)) }

      it "fails if you cannot bulk invite to the forum" do
        sign_in(Fabricate(:user))
        post "/invites/upload_csv.json", params: { file: file, name: "discourse.csv" }
        expect(response.status).to eq(403)
      end

      it "allows admin to bulk invite" do
        sign_in(admin)
        post "/invites/upload_csv.json", params: { file: file, name: "discourse.csv" }
        expect(response.status).to eq(200)
        expect(Jobs::BulkInvite.jobs.size).to eq(1)
      end

      it "allows admin to bulk invite when DiscourseConnect enabled" do
        SiteSetting.discourse_connect_url = "https://example.com"
        SiteSetting.enable_discourse_connect = true

        sign_in(admin)
        post "/invites/upload_csv.json", params: { file: file, name: "discourse.csv" }
        expect(response.status).to eq(200)
        expect(Jobs::BulkInvite.jobs.size).to eq(1)
      end

      it "sends limited invites at a time" do
        SiteSetting.max_bulk_invites = 3
        sign_in(admin)
        post "/invites/upload_csv.json", params: { file: file, name: "discourse.csv" }

        expect(response.status).to eq(422)
        expect(Jobs::BulkInvite.jobs.size).to eq(1)
        expect(response.parsed_body["errors"][0]).to eq(
          I18n.t("bulk_invite.max_rows", max_bulk_invites: SiteSetting.max_bulk_invites),
        )
      end

      it "can import user fields" do
        Jobs.run_immediately!
        user_field = Fabricate(:user_field, name: "location")
        Fabricate(:group, name: "discourse")
        Fabricate(:group, name: "ubuntu")

        sign_in(admin)

        post "/invites/upload_csv.json",
             params: {
               file: file_with_headers,
               name: "discourse_headers.csv",
             }
        expect(response.status).to eq(200)

        user = User.where(staged: true).find_by_email("test@example.com")
        expect(user.user_fields[user_field.id.to_s]).to eq("usa")

        user2 = User.where(staged: true).find_by_email("test2@example.com")
        expect(user2.user_fields[user_field.id.to_s]).to eq("europe")
      end

      it "can pre-set user locales" do
        Jobs.run_immediately!
        sign_in(admin)

        post "/invites/upload_csv.json",
             params: {
               file: file_with_locales,
               name: "discourse_headers.csv",
             }
        expect(response.status).to eq(200)

        user = User.where(staged: true).find_by_email("test@example.com")
        expect(user.locale).to eq("de")

        user2 = User.where(staged: true).find_by_email("test2@example.com")
        expect(user2.locale).to eq("pl")
      end
    end
  end
end
