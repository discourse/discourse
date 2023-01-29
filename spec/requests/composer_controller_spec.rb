# frozen_string_literal: true

RSpec.describe ComposerController do
  describe "#mentions" do
    fab!(:current_user) { Fabricate(:user) }
    fab!(:user) { Fabricate(:user) }

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

    before { sign_in(current_user) }

    context "without a topic" do
      it "finds mentions" do
        get "/composer/mentions.json",
            params: {
              names: [
                "invaliduserorgroup",
                user.username,
                group.name,
                invisible_group.name,
                unmessageable_group.name,
                unmentionable_group.name,
              ],
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["users"]).to contain_exactly(user.username)
        expect(response.parsed_body["user_reasons"]).to eq({})

        expect(response.parsed_body["groups"]).to eq(
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
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(
          { unmentionable_group.name => "not_mentionable" },
        )

        expect(response.parsed_body["max_users_notified_per_group_mention"]).to eq(
          SiteSetting.max_users_notified_per_group_mention,
        )
      end
    end

    context "with a regular topic" do
      fab!(:topic) { Fabricate(:topic) }

      it "finds mentions" do
        get "/composer/mentions.json",
            params: {
              names: [
                "invaliduserorgroup",
                user.username,
                group.name,
                invisible_group.name,
                unmessageable_group.name,
                unmentionable_group.name,
              ],
              topic_id: topic.id,
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["users"]).to contain_exactly(user.username)
        expect(response.parsed_body["user_reasons"]).to eq({})

        expect(response.parsed_body["groups"]).to eq(
          group.name => {
            "user_count" => group.user_count,
          },
          unmessageable_group.name => {
            "user_count" => unmessageable_group.user_count,
          },
          unmentionable_group.name => {
            "user_count" => unmentionable_group.user_count,
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(
          unmentionable_group.name => "not_mentionable",
        )

        expect(response.parsed_body["max_users_notified_per_group_mention"]).to eq(
          SiteSetting.max_users_notified_per_group_mention,
        )
      end
    end

    context "with a private message" do
      fab!(:allowed_user) { Fabricate(:user) }
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
              names: [
                "invaliduserorgroup",
                user.username,
                allowed_user.username,
                group.name,
                invisible_group.name,
                unmessageable_group.name,
                unmentionable_group.name,
              ],
              topic_id: topic.id,
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["users"]).to contain_exactly(
          user.username,
          allowed_user.username,
        )
        expect(response.parsed_body["user_reasons"]).to eq(user.username => "private")

        expect(response.parsed_body["groups"]).to eq(
          group.name => {
            "user_count" => group.user_count,
          },
          unmessageable_group.name => {
            "user_count" => unmessageable_group.user_count,
          },
          unmentionable_group.name => {
            "user_count" => unmentionable_group.user_count,
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(
          group.name => "not_allowed",
          unmessageable_group.name => "not_allowed",
          unmentionable_group.name => "not_mentionable",
        )

        expect(response.parsed_body["max_users_notified_per_group_mention"]).to eq(
          SiteSetting.max_users_notified_per_group_mention,
        )
      end

      it "returns notified_count" do
        sign_in(allowed_user)
        group.add(user)
        topic.invite_group(Discourse.system_user, group)

        other_group = Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
        other_group.add(allowed_user)
        other_group.add(user)
        other_group.add(Fabricate(:user))

        # Trying to mention other_group which has not been invited, but two of
        # its members have been (allowed_user directly and user via group).
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
      fab!(:allowed_user) { Fabricate(:user) }

      it "finds mentions" do
        get "/composer/mentions.json",
            params: {
              names: [
                "invaliduserorgroup",
                user.username,
                allowed_user.username,
                group.name,
                invisible_group.name,
                unmessageable_group.name,
                unmentionable_group.name,
              ],
              allowed_names: [allowed_user.username, unmentionable_group.name],
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["users"]).to contain_exactly(
          user.username,
          allowed_user.username,
        )
        expect(response.parsed_body["user_reasons"]).to eq(user.username => "private")

        expect(response.parsed_body["groups"]).to eq(
          group.name => {
            "user_count" => group.user_count,
          },
          unmessageable_group.name => {
            "user_count" => unmessageable_group.user_count,
          },
          unmentionable_group.name => {
            "user_count" => unmentionable_group.user_count,
          },
        )
        expect(response.parsed_body["group_reasons"]).to eq(
          group.name => "not_allowed",
          unmessageable_group.name => "not_allowed",
          unmentionable_group.name => "not_mentionable",
        )

        expect(response.parsed_body["max_users_notified_per_group_mention"]).to eq(
          SiteSetting.max_users_notified_per_group_mention,
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

    context "with an invalid topic" do
      it "returns an error" do
        get "/composer/mentions.json",
            params: {
              names: [
                "invaliduserorgroup",
                user.username,
                group.name,
                invisible_group.name,
                unmessageable_group.name,
                unmentionable_group.name,
              ],
              topic_id: -1,
            }

        expect(response.status).to eq(403)
      end
    end
  end
end
