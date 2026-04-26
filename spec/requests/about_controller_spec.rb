# frozen_string_literal: true

RSpec.describe AboutController do
  describe "#index" do
    it "should display the about page for anonymous user when login_required is false" do
      SiteSetting.login_required = false
      get "/about"

      expect(response.status).to eq(200)
      expect(response.body).to include("<title>About - Discourse</title>")
    end

    it "should redirect to login page for anonymous user when login_required is true" do
      SiteSetting.login_required = true
      get "/about"

      expect(response).to redirect_to "/login"
    end

    it "should display the about page for logged in user when login_required is true" do
      SiteSetting.login_required = true
      sign_in(Fabricate(:user))
      get "/about"

      expect(response.status).to eq(200)
    end

    context "with crawler view" do
      it "should include correct title" do
        get "/about", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("<title>About - Discourse</title>")
      end

      it "should include correct user URLs" do
        Fabricate(:admin, username: "anAdminUser")
        get "/about", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("/u/anadminuser")
      end

      it "supports unicode usernames" do
        SiteSetting.unicode_usernames = true
        Fabricate(:admin, username: "martínez")
        get "/about", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("/u/mart%25C3%25ADnez")
      end
    end

    it "serializes stats when 'Guardian#can_see_about_stats?' is true" do
      Guardian.any_instance.stubs(:can_see_about_stats?).returns(true)
      get "/about.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["about"].keys).to include("stats")
    end

    it "does not serialize stats when 'Guardian#can_see_about_stats?' is false" do
      Guardian.any_instance.stubs(:can_see_about_stats?).returns(false)
      get "/about.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["about"].keys).not_to include("stats")
    end

    context "with profile visibility controls" do
      fab!(:admin)
      fab!(:moderator)

      def user_ids_from(key)
        response.parsed_body["about"]["#{key}_ids"] || []
      end

      context "when hide_user_profiles_from_public is enabled" do
        before { SiteSetting.hide_user_profiles_from_public = true }

        it "does not expose admins and moderators to anonymous users" do
          get "/about.json"

          expect(response.status).to eq(200)
          expect(user_ids_from("admin")).to be_empty
          expect(user_ids_from("moderator")).to be_empty
        end

        it "exposes admins and moderators to logged in users" do
          sign_in(Fabricate(:user))
          get "/about.json"

          expect(response.status).to eq(200)
          expect(user_ids_from("admin")).to include(admin.id)
          expect(user_ids_from("moderator")).to include(moderator.id)
        end
      end

      context "when a staff member has hide_profile enabled" do
        before do
          SiteSetting.allow_users_to_hide_profile = true
          admin.user_option.update!(hide_profile: true)
        end

        it "excludes them from the about page for anonymous users" do
          get "/about.json"

          expect(response.status).to eq(200)
          expect(user_ids_from("admin")).not_to include(admin.id)
        end

        it "excludes them from the about page for regular users" do
          sign_in(Fabricate(:user))
          get "/about.json"

          expect(response.status).to eq(200)
          expect(user_ids_from("admin")).not_to include(admin.id)
        end

        it "still shows them to staff users" do
          sign_in(Fabricate(:admin))
          get "/about.json"

          expect(response.status).to eq(200)
          expect(user_ids_from("admin")).to include(admin.id)
        end
      end

      context "with category moderators" do
        fab!(:group, :public_group)
        fab!(:category_mod) { Fabricate(:user, last_seen_at: 1.day.ago) }
        fab!(:category)
        fab!(:category_moderation_group) do
          group.add(category_mod)
          Fabricate(:category_moderation_group, category: category, group: group)
        end

        it "does not expose category moderators to anonymous users when hide_user_profiles_from_public is enabled" do
          SiteSetting.hide_user_profiles_from_public = true
          get "/about.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body["about"]["category_moderators"]).to be_empty
        end

        it "excludes category moderators with hide_profile enabled" do
          SiteSetting.allow_users_to_hide_profile = true
          category_mod.user_option.update!(hide_profile: true)

          get "/about.json"

          expect(response.status).to eq(200)
          all_mod_ids =
            response.parsed_body["about"]["category_moderators"].flat_map do |cm|
              cm["moderator_ids"]
            end
          expect(all_mod_ids).not_to include(category_mod.id)
        end
      end
    end
  end
end
