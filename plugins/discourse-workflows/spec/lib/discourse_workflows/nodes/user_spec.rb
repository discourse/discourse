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

    it "updates the bio and title", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "operation" => "edit",
            "username" => user.username,
            "updates" => {
              "bio_raw" => "Updated bio",
              "title" => "Updated title",
            },
            "actor_username" => admin.username,
          },
        )

      expect(user.reload.user_profile.bio_raw).to eq("Updated bio")
      expect(user.title).to eq("Updated title")
      expect(result.dig("user", "bio_raw")).to eq("Updated bio")
      expect(result.dig("user", "title")).to eq("Updated title")
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
end
