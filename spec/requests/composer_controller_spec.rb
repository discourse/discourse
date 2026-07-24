# frozen_string_literal: true

RSpec.describe ComposerController do
  describe "#mentions" do
    fab!(:current_user, :user)
    fab!(:user)

    fab!(:group) do
      Fabricate(
        :group,
        messageable_level: Group::ALIAS_LEVELS[:everyone],
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
      )
    end
    fab!(:invisible_group) { Fabricate(:group, visibility_level: Group.visibility_levels[:owners]) }
    fab!(:unmessageable_group) do
      Fabricate(
        :group,
        messageable_level: Group::ALIAS_LEVELS[:nobody],
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
      )
    end
    fab!(:unmentionable_group) do
      Fabricate(
        :group,
        messageable_level: Group::ALIAS_LEVELS[:everyone],
        mentionable_level: Group::ALIAS_LEVELS[:nobody],
      )
    end

    let(:base_names) do
      [
        "invaliduserorgroup",
        user.username,
        group.name,
        invisible_group.name,
        unmessageable_group.name,
        unmentionable_group.name,
      ]
    end

    let(:expected_groups) do
      {
        group.name => {
          "user_count" => group.user_count,
        },
        unmessageable_group.name => {
          "user_count" => unmessageable_group.user_count,
        },
        unmentionable_group.name => {
          "user_count" => unmentionable_group.user_count,
        },
      }
    end

    before { sign_in(current_user) }

    context "without a topic" do
      it "finds mentions" do
        get "/composer/mentions.json", params: { names: base_names }

        expect(response.status).to eq(200)
        expect(response.parsed_body["users"]).to contain_exactly(user.username)
        expect(response.parsed_body["user_reasons"]).to eq({})
        expect(response.parsed_body["groups"]).to eq(expected_groups)
        expect(response.parsed_body["group_reasons"]).to eq(
          unmentionable_group.name => "not_mentionable",
        )
      end
    end

    context "with a regular topic" do
      fab!(:topic)

      it "finds mentions" do
        get "/composer/mentions.json", params: { names: base_names, topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(response.parsed_body["users"]).to contain_exactly(user.username)
        expect(response.parsed_body["user_reasons"]).to eq({})
        expect(response.parsed_body["groups"]).to eq(expected_groups)
        expect(response.parsed_body["group_reasons"]).to eq(
          unmentionable_group.name => "not_mentionable",
        )
      end
    end

    context "with a private message" do
      fab!(:allowed_user, :user)
      fab!(:topic) { Fabricate(:private_message_topic, user: allowed_user) }

      it "does not work if topic is not visible" do
        get "/composer/mentions.json",
            params: {
              names: [allowed_user.username],
              topic_id: topic.id,
            }

        expect(response.status).to eq(403)
      end

      it "finds mentions" do
        sign_in(allowed_user)
        topic.invite_group(Discourse.system_user, unmentionable_group)

        get "/composer/mentions.json",
            params: {
              names: base_names + [allowed_user.username],
              topic_id: topic.id,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["users"]).to contain_exactly(
          user.username,
          allowed_user.username,
        )
        expect(response.parsed_body["user_reasons"]).to eq(user.username => "private")
        expect(response.parsed_body["groups"]).to eq(expected_groups)
        expect(response.parsed_body["group_reasons"]).to eq(
          group.name => "not_allowed",
          unmessageable_group.name => "not_allowed",
          unmentionable_group.name => "not_mentionable",
        )
      end

      it "returns notified_count" do
        sign_in(allowed_user)
        group.add(user)
        topic.invite_group(Discourse.system_user, group)

        other_group = Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
        other_group.add(allowed_user)
        other_group.add(user)

        # Trying to mention other_group which has not been invited, but two of
        # its members have been (allowed_user directly and user via group).
        get "/composer/mentions.json", params: { names: [other_group.name], topic_id: topic.id }

        expect(response.status).to eq(200)

        expect(response.parsed_body["groups"]).to eq(other_group.name => { "user_count" => 2 })
        expect(response.parsed_body["group_reasons"]).to be_empty

        other_group.add(Fabricate(:user))

        get "/composer/mentions.json", params: { names: [other_group.name], topic_id: topic.id }

        expect(response.status).to eq(200)

        expect(response.parsed_body["groups"]).to eq(
          other_group.name => {
            "user_count" => 3,
            "notified_count" => 2,
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(other_group.name => "some_not_allowed")
      end
    end

    context "with a new private message" do
      fab!(:allowed_user, :user)

      it "finds mentions" do
        get "/composer/mentions.json",
            params: {
              names: base_names + [allowed_user.username],
              allowed_names: [allowed_user.username, unmentionable_group.name],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["users"]).to contain_exactly(
          user.username,
          allowed_user.username,
        )
        expect(response.parsed_body["user_reasons"]).to eq(user.username => "private")
        expect(response.parsed_body["groups"]).to eq(expected_groups)
        expect(response.parsed_body["group_reasons"]).to eq(
          group.name => "not_allowed",
          unmessageable_group.name => "not_allowed",
          unmentionable_group.name => "not_mentionable",
        )
      end

      it "returns notified_count" do
        sign_in(allowed_user)
        group.add(user)

        other_group = Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
        other_group.add(allowed_user)
        other_group.add(user)
        other_group.add(Fabricate(:user))

        # Trying to mention other_group which has not been invited, but two of
        # its members have been (allowed_user directly and user via group).
        get "/composer/mentions.json",
            params: {
              names: [other_group.name],
              allowed_names: [allowed_user.username, group.name],
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["groups"]).to eq(
          other_group.name => {
            "user_count" => 3,
            "notified_count" => 2,
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(other_group.name => "some_not_allowed")
      end
    end

    context "with a new private message to a group with hidden members" do
      fab!(:alice) { Fabricate(:user, username: "alice") }
      fab!(:bob) { Fabricate(:user, username: "bob") }
      fab!(:hidden_members_group) do
        Fabricate(
          :group,
          messageable_level: Group::ALIAS_LEVELS[:everyone],
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
          members_visibility_level: Group.visibility_levels[:staff],
        )
      end

      before { hidden_members_group.add(alice) }

      it "does not leak hidden group membership via user_reasons" do
        get "/composer/mentions.json",
            params: {
              names: [alice.username, bob.username],
              allowed_names: [hidden_members_group.name],
            }

        expect(response.status).to eq(200)

        user_reasons = response.parsed_body["user_reasons"]
        expect(user_reasons[alice.username]).to eq(user_reasons[bob.username])
      end
    end

    context "with a group with hidden members" do
      fab!(:hidden_members_group) do
        Fabricate(
          :group,
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
          members_visibility_level: Group.visibility_levels[:owners],
          users: [Fabricate(:user)],
        )
      end

      it "does not return the member count" do
        get "/composer/mentions.json", params: { names: [hidden_members_group.name] }

        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"]).to eq(hidden_members_group.name => {})
      end
    end

    context "with invalid allowed_names parameter" do
      it "returns 400 when allowed_names is not an array" do
        get "/composer/mentions.json",
            params: {
              names: [user.username],
              allowed_names: "not_an_array",
            }

        expect(response.status).to eq(400)
      end
    end

    context "with mixed-case names" do
      fab!(:mixed_case_user) { Fabricate(:user, username: "SomeUser") }
      fab!(:mixed_case_group) do
        Fabricate(
          :group,
          name: "MixedCaseGroup",
          messageable_level: Group::ALIAS_LEVELS[:everyone],
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      end

      before { sign_in(Fabricate(:admin)) }

      it "matches users case-insensitively when checking category access" do
        category = Fabricate(:private_category, group: mixed_case_group)
        topic_in_category = Fabricate(:topic, category: category)

        get "/composer/mentions.json",
            params: {
              names: [mixed_case_user.username, mixed_case_user.username.upcase],
              topic_id: topic_in_category.id,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["users"]).to contain_exactly("someuser")
        expect(response.parsed_body["user_reasons"]).to eq("someuser" => "category")
      end

      it "matches mentionable groups case-insensitively" do
        get "/composer/mentions.json",
            params: {
              names: [mixed_case_group.name.upcase, mixed_case_group.name.downcase],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"]).to eq(
          "mixedcasegroup" => {
            "user_count" => mixed_case_group.user_count,
          },
        )
        expect(response.parsed_body["group_reasons"]).to be_empty
      end

      it "matches mentioned groups case-insensitively in private messages" do
        pm = Fabricate(:private_message_topic)

        get "/composer/mentions.json",
            params: {
              names: [mixed_case_group.name.upcase],
              topic_id: pm.id,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["group_reasons"]).to eq("mixedcasegroup" => "not_allowed")
      end

      it "matches allowed_names users case-insensitively" do
        get "/composer/mentions.json",
            params: {
              names: [mixed_case_user.username.upcase],
              allowed_names: [mixed_case_user.username.upcase],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["user_reasons"]).to eq({})
      end

      it "matches allowed_names groups case-insensitively" do
        get "/composer/mentions.json",
            params: {
              names: [mixed_case_group.name.upcase],
              allowed_names: [mixed_case_group.name.upcase],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["group_reasons"]).to be_empty
      end
    end

    context "with the composer_mention_user_reason modifier" do
      fab!(:modified_user) { Fabricate(:user, username: "ModifiedReason") }
      fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
      fab!(:restricted_topic) { Fabricate(:topic, category: private_category) }

      before { sign_in(Fabricate(:admin)) }

      it "lets a plugin clear the reachability reason" do
        target_id = modified_user.id
        modifier = Proc.new { |reason, user| user.id == target_id ? nil : reason }
        plugin_instance = Plugin::Instance.new
        DiscoursePluginRegistry.register_modifier(
          plugin_instance,
          :composer_mention_user_reason,
          &modifier
        )

        begin
          get "/composer/mentions.json",
              params: {
                names: [modified_user.username],
                topic_id: restricted_topic.id,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["users"]).to contain_exactly(modified_user.username.downcase)
          expect(response.parsed_body["user_reasons"]).to eq({})
        ensure
          DiscoursePluginRegistry.unregister_modifier(
            plugin_instance,
            :composer_mention_user_reason,
            &modifier
          )
        end
      end

      it "still returns the reachability reason without the modifier" do
        get "/composer/mentions.json",
            params: {
              names: [modified_user.username],
              topic_id: restricted_topic.id,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["user_reasons"]).to eq(
          modified_user.username.downcase => "category",
        )
      end
    end

    context "with an invalid topic" do
      it "returns an error" do
        get "/composer/mentions.json", params: { names: base_names, topic_id: -1 }

        expect(response.status).to eq(403)
      end
    end
  end
end
