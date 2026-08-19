# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::User::V1 do
  fab!(:user)
  fab!(:admin)

  describe "#execute" do
    it "gets user fields and group memberships", :aggregate_failures do
      user.user_profile.update!(bio_raw: "Original bio")
      user.update!(title: "Original title", manual_locked_trust_level: TrustLevel[1])
      user_field = Fabricate(:user_field)
      user.set_user_field(user_field.id, "Field value")
      user.save_custom_fields
      public_group = Fabricate(:group, name: "public_group")
      staff_group =
        Fabricate(
          :group,
          name: "staff_group",
          visibility_level: Group.visibility_levels[:staff],
          members_visibility_level: Group.visibility_levels[:staff],
        )
      public_group.add(user)
      staff_group.add(user)

      result = execute_node(configuration: { "operation" => "get", "username" => user.username })

      expect(result["user"]).to include(
        "id" => user.id,
        "username" => user.username,
        "title" => "Original title",
        "bio_raw" => "Original bio",
        "manual_locked_trust_level" => TrustLevel[1],
        "trust_level_locked" => true,
      )
      expect(result.dig("user", "user_fields")).to include(user_field.id.to_s => "Field value")
      expect(result.dig("user", "groups").map { |group| group["name"] }).to include(
        public_group.name,
        staff_group.name,
      )
      expect(result["user"]).not_to have_key("email")
    end

    it "returns profile images and website", :aggregate_failures do
      avatar = Fabricate(:upload)
      profile_background = Fabricate(:upload)
      card_background = Fabricate(:upload)
      user.update!(uploaded_avatar_id: avatar.id)
      user.user_profile.update!(
        website: "https://example.com",
        profile_background_upload_id: profile_background.id,
        card_background_upload_id: card_background.id,
      )

      result = execute_node(configuration: { "operation" => "get", "username" => user.username })

      expect(result["user"]).to include(
        "uploaded_avatar_id" => avatar.id,
        "website" => "https://example.com",
        "profile_background_upload_id" => profile_background.id,
        "card_background_upload_id" => card_background.id,
      )
      expect(result.dig("user", "avatar_template")).to include(avatar.id.to_s)
      expect(
        DiscourseWorkflows::Schema::USER_ACTION_SCHEMA.dig(
          "properties",
          "user",
          "properties",
        ).keys - result["user"].keys,
      ).to be_empty
    end

    it "always returns account status signals", :aggregate_failures do
      user.update!(silenced_till: 1.day.from_now, approved: true)

      result = execute_node(configuration: { "operation" => "get", "username" => user.username })

      expect(result["user"]).to include(
        "silenced" => true,
        "suspended" => false,
        "approved" => true,
      )
      expect(result.dig("user", "created_at")).to be_present
    end

    it "returns reading and posting stats when requested", :aggregate_failures do
      user.user_stat.update!(time_read: 42, posts_read_count: 7, topics_entered: 3, post_count: 2)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["stats"],
          },
        )

      expect(result.dig("user", "stats")).to include(
        "time_read" => 42,
        "posts_read_count" => 7,
        "topics_entered" => 3,
        "post_count" => 2,
      )
    end

    it "returns emails when requested, and logs the check", :aggregate_failures do
      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "username" => user.username,
              "include_extensions" => ["emails"],
              "actor_username" => admin.username,
            },
          )

        expect(result.dig("user", "email")).to eq(user.email)
        expect(result.dig("user", "secondary_emails")).to eq([])
      end.to change {
        UserHistory.where(action: UserHistory.actions[:check_email], target_user_id: user.id).count
      }.by(1)
    end

    it "hides emails from actors who cannot check them", :aggregate_failures do
      SiteSetting.moderators_view_emails = false
      moderator = Fabricate(:moderator)

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "username" => user.username,
              "include_extensions" => ["emails"],
              "actor_username" => moderator.username,
            },
          )

        expect(result.dig("user", "email")).to eq(nil)
        expect(result.dig("user", "secondary_emails")).to eq([])
      end.not_to change { UserHistory.where(action: UserHistory.actions[:check_email]).count }
    end

    it "returns ip addresses and their locations when requested", :aggregate_failures do
      user.update!(registration_ip_address: "1.1.1.1", ip_address: "2.2.2.2")
      DiscourseIpInfo
        .stubs(:get)
        .with("1.1.1.1")
        .returns({ country: "France", country_code: "FR", location: "Paris, France" })
      DiscourseIpInfo
        .stubs(:get)
        .with("2.2.2.2")
        .returns({ country: "Japan", country_code: "JP", location: "Tokyo, Japan" })

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["ips"],
          },
        )

      expect(result.dig("user", "registration_ip_address")).to eq("1.1.1.1")
      expect(result.dig("user", "ip_address")).to eq("2.2.2.2")
      expect(result.dig("user", "registration_location", "country")).to eq("France")
      expect(result.dig("user", "last_location", "country")).to eq("Japan")
    end

    it "returns a null location when the maxmind databases are unavailable" do
      user.update!(registration_ip_address: "1.1.1.1", ip_address: nil)
      DiscourseIpInfo.stubs(:get).returns({})

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["ips"],
          },
        )

      expect(result.dig("user", "registration_location")).to eq(nil)
    end

    it "hides ip addresses from actors who cannot see them", :aggregate_failures do
      user.update!(registration_ip_address: "1.1.1.1", ip_address: "2.2.2.2")
      SiteSetting.moderators_view_ips = false
      moderator = Fabricate(:moderator)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["ips"],
            "actor_username" => moderator.username,
          },
        )

      expect(result.dig("user", "registration_ip_address")).to eq(nil)
      expect(result.dig("user", "ip_address")).to eq(nil)
      expect(result.dig("user", "last_location")).to eq(nil)
    end

    it "combines several extensions in one payload", :aggregate_failures do
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")
      user.user_stat.update!(time_read: 11)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => %w[stats external_ids],
          },
        )

      expect(result.dig("user", "external_id")).to eq("ext-42")
      expect(result.dig("user", "stats", "time_read")).to eq(11)
      expect(result["user"]).not_to have_key("email")
    end

    it "returns external identity provider ids when requested", :aggregate_failures do
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")
      Fabricate(:user_associated_account, user: user, provider_name: "oidc", provider_uid: "uid-7")

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["external_ids"],
          },
        )

      expect(result.dig("user", "external_id")).to eq("ext-42")
      expect(result.dig("user", "external_ids")).to eq("oidc" => "uid-7")
    end

    it "omits extensions that were not requested", :aggregate_failures do
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")

      result = execute_node(configuration: { "operation" => "get", "username" => user.username })

      expect(result["user"]).not_to have_key("external_id")
      expect(result["user"]).not_to have_key("external_ids")
    end

    it "raises when an unknown extension is requested" do
      expect do
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => %w[external_ids nope],
          },
        )
      end.to raise_error(DiscourseWorkflows::NodeError, "Unknown user extensions: nope.")
    end

    it "removes the avatar and logs a staff action", :aggregate_failures do
      avatar = Fabricate(:upload)
      user.update!(uploaded_avatar_id: avatar.id)
      user.user_avatar.update!(custom_upload_id: avatar.id)

      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "remove_avatar" => true,
            },
            "actor_username" => admin.username,
          },
        )

      expect(result.dig("user", "uploaded_avatar_id")).to be_nil
      expect(user.reload.user_avatar.custom_upload_id).to be_nil
      expect(
        UserHistory.where(
          action: UserHistory.actions[:removed_avatar],
          target_user_id: user.id,
        ).count,
      ).to eq(1)
    end

    it "leaves the avatar alone when the flag is not set", :aggregate_failures do
      avatar = Fabricate(:upload)
      user.update!(uploaded_avatar_id: avatar.id)

      execute_node(
        configuration: {
          "operation" => "edit",
          "username" => user.username,
          "updates" => {
            "remove_avatar" => false,
            "title" => "Kept",
          },
          "actor_username" => admin.username,
        },
      )

      expect(user.reload.uploaded_avatar_id).to eq(avatar.id)
    end

    it "clears the profile and card backgrounds", :aggregate_failures do
      profile_background = Fabricate(:upload)
      card_background = Fabricate(:upload)
      user.user_profile.update!(
        profile_background_upload_id: profile_background.id,
        card_background_upload_id: card_background.id,
      )

      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "remove_profile_background" => true,
              "remove_card_background" => true,
            },
            "actor_username" => admin.username,
          },
        )

      expect(result.dig("user", "profile_background_upload_id")).to be_nil
      expect(result.dig("user", "card_background_upload_id")).to be_nil
    end

    it "returns external ids from the edit operation", :aggregate_failures do
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")

      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "title" => "Updated title",
            },
            "include_extensions" => ["external_ids"],
            "actor_username" => admin.username,
          },
        )

      expect(result.dig("user", "external_id")).to eq("ext-42")
    end

    it "hides external ids from actors who cannot see them", :aggregate_failures do
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")
      Fabricate(:user_associated_account, user: user, provider_name: "oidc", provider_uid: "uid-7")
      SiteSetting.moderators_view_sso_details = false
      moderator = Fabricate(:moderator)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["external_ids"],
            "actor_username" => moderator.username,
          },
        )

      expect(result.dig("user", "external_id")).to eq(nil)
      expect(result.dig("user", "external_ids")).to eq({})
    end

    it "returns the connect external id to moderators when the site setting allows it" do
      SiteSetting.moderators_view_sso_details = true
      Fabricate(:single_sign_on_record, user: user, external_id: "ext-42")
      moderator = Fabricate(:moderator)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "include_extensions" => ["external_ids"],
            "actor_username" => moderator.username,
          },
        )

      expect(result.dig("user", "external_id")).to eq("ext-42")
    end

    it "updates the bio, title, website and location", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "bio_raw" => "Updated bio",
              "title" => "Updated title",
              "website" => "https://example.com",
              "location" => "Paris",
            },
            "actor_username" => admin.username,
          },
        )

      expect(user.reload.user_profile.bio_raw).to eq("Updated bio")
      expect(user.title).to eq("Updated title")
      expect(user.user_profile.location).to eq("Paris")
      expect(result.dig("user", "bio_raw")).to eq("Updated bio")
      expect(result.dig("user", "title")).to eq("Updated title")
      expect(result.dig("user", "website")).to eq("https://example.com")
    end

    it "only changes fields included in updates", :aggregate_failures do
      user.user_profile.update!(bio_raw: "Existing bio")
      user.update!(title: "Existing title")

      execute_node(
        configuration: {
          "operation" => "edit",
          "username" => user.username,
          "updates" => {
            "title" => "Updated title",
          },
          "actor_username" => admin.username,
        },
      )

      expect(user.reload.title).to eq("Updated title")
      expect(user.user_profile.bio_raw).to eq("Existing bio")
    end

    it "changes and locks the trust level", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "trust_level" => "2",
              "trust_level_locked" => true,
            },
            "actor_username" => admin.username,
          },
        )

      expect(user.reload.trust_level).to eq(TrustLevel[2])
      expect(user.manual_locked_trust_level).to eq(TrustLevel[2])
      expect(result.dig("user", "trust_level")).to eq(TrustLevel[2])
      expect(result.dig("user", "trust_level_locked")).to eq(true)
    end

    it "unlocks the trust level", :aggregate_failures do
      user.update!(manual_locked_trust_level: TrustLevel[2], trust_level: TrustLevel[2])

      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "trust_level_locked" => false,
            },
            "actor_username" => admin.username,
          },
        )

      expect(user.reload.manual_locked_trust_level).to be_nil
      expect(result.dig("user", "trust_level_locked")).to eq(false)
    end

    it "raises when the actor cannot edit profile fields" do
      other_user = Fabricate(:user)

      expect do
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "bio_raw" => "Denied bio",
            },
            "actor_username" => other_user.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "raises when the actor cannot change trust level" do
      expect do
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "trust_level" => "2",
            },
            "actor_username" => user.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "raises when the trust level is invalid" do
      expect do
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "trust_level" => "9",
            },
          },
        )
      end.to raise_error(DiscourseWorkflows::NodeError, "Invalid trust level: \"9\".")
    end

    it "supports legacy top-level updates", :aggregate_failures do
      user.user_profile.update!(bio_raw: "Existing bio")
      user.update!(title: "Existing title")

      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "bio_raw" => "",
            "title" => "",
            "trust_level" => "2",
            "trust_level_locked" => true,
            "actor_username" => admin.username,
          },
        )

      expect(user.reload.user_profile.bio_raw).to eq("")
      expect(user.title).to eq("")
      expect(user.trust_level).to eq(TrustLevel[2])
      expect(user.manual_locked_trust_level).to eq(TrustLevel[2])
      expect(result.dig("user", "bio_raw")).to eq("")
      expect(result.dig("user", "title")).to eq("")
      expect(result.dig("user", "trust_level_locked")).to eq(true)
    end

    it "raises when the actor cannot see the profile" do
      SiteSetting.allow_users_to_hide_profile = true
      user.user_option.update!(hide_profile: true)
      other_user = Fabricate(:user)

      expect do
        execute_node(
          configuration: {
            "operation" => "get",
            "username" => user.username,
            "actor_username" => other_user.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "raises when the operation is unknown" do
      expect do
        execute_node(configuration: { "operation" => "delete", "username" => user.username })
      end.to raise_error(DiscourseWorkflows::NodeError, "Unknown operation: delete.")
    end

    it "raises when updates is not an object" do
      expect do
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => "title",
          },
        )
      end.to raise_error(DiscourseWorkflows::NodeError, "User updates must be an object.")
    end

    it "raises when the user does not exist" do
      expect do
        execute_node(configuration: { "operation" => "get", "username" => "missing_user" })
      end.to raise_error(DiscourseWorkflows::NodeError, "User 'missing_user' not found")
    end
  end

  describe ".output_schemas" do
    def user_properties(configuration)
      described_class.output_schemas(configuration).first.dig("properties", "user", "properties")
    end

    it "only advertises the extensions the node was configured with", :aggregate_failures do
      expect(user_properties({}).keys).to include("username", "created_at", "groups")
      expect(user_properties({}).keys).not_to include(
        "stats",
        "external_id",
        "email",
        "ip_address",
        "last_location",
      )
    end

    it "advertises each selected extension", :aggregate_failures do
      stats_only = user_properties("include_extensions" => ["stats"])
      ips_and_emails = user_properties("include_extensions" => %w[ips emails])

      expect(stats_only.keys).to include("stats")
      expect(stats_only.keys).not_to include("email")
      expect(ips_and_emails.keys).to include(
        "email",
        "secondary_emails",
        "registration_ip_address",
        "registration_location",
        "ip_address",
        "last_location",
      )
      expect(ips_and_emails.keys).not_to include("stats")
    end

    it "advertises every extension when the selection is an expression" do
      properties = user_properties("include_extensions" => "={{ $json.extensions }}")

      expect(properties.keys).to include("stats", "external_id", "email", "ip_address")
    end
  end
end
