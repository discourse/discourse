# frozen_string_literal: true

RSpec.describe Chat::Api::HintsController do
  describe "#check_group_mentions" do
    context "for anons" do
      it "returns a 404" do
        get "/chat/api/mentions/groups", params: { mentions: %w[group1] }

        expect(response.status).to eq(403)
      end
    end

    context "for logged in users" do
      fab!(:user) { Fabricate(:user) }
      fab!(:mentionable_group) do
        Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
      end
      fab!(:admin_mentionable_group) do
        Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:only_admins])
      end

      before { sign_in(user) }

      it "returns a 400 when no mentions are given" do
        get "/chat/api/mentions/groups"

        expect(response.status).to eq(400)
      end

      it "returns a warning when a group is not mentionable" do
        get "/chat/api/mentions/groups",
            params: {
              mentions: [mentionable_group.name, admin_mentionable_group.name],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["unreachable"]).to contain_exactly(admin_mentionable_group.name)
      end

      it "returns no warning if the user is allowed to mention" do
        user.update!(admin: true)
        get "/chat/api/mentions/groups",
            params: {
              mentions: [mentionable_group.name, admin_mentionable_group.name],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["unreachable"]).to be_empty
      end

      it "returns a warning if the group has too many users" do
        user_1 = Fabricate(:user)
        user_2 = Fabricate(:user)
        mentionable_group.add(user_1)
        mentionable_group.add(user_2)
        SiteSetting.max_users_notified_per_group_mention = 1

        get "/chat/api/mentions/groups",
            params: {
              mentions: [mentionable_group.name, admin_mentionable_group.name],
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["over_members_limit"]).to contain_exactly(
          mentionable_group.name,
        )
      end

      it "returns no warnings when the group doesn't exist" do
        get "/chat/api/mentions/groups", params: { mentions: ["a_fake_group"] }

        expect(response.status).to eq(200)
        expect(response.parsed_body["unreachable"]).to be_empty
        expect(response.parsed_body["over_members_limit"]).to be_empty
      end

      it "doesn't leak groups that are not visible" do
        invisible_group =
          Fabricate(
            :group,
            visibility_level: Group.visibility_levels[:staff],
            mentionable_level: Group::ALIAS_LEVELS[:only_admins],
          )

        get "/chat/api/mentions/groups", params: { mentions: [invisible_group.name] }

        expect(response.status).to eq(200)
        expect(response.parsed_body["unreachable"]).to be_empty
        expect(response.parsed_body["over_members_limit"]).to be_empty
        expect(response.parsed_body["invalid"]).to contain_exactly(invisible_group.name)
      end

      it "triggers a rate-limit on too many requests" do
        RateLimiter.enable

        5.times { get "/chat/api/mentions/groups", params: { mentions: [mentionable_group.name] } }

        get "/chat/api/mentions/groups", params: { mentions: [mentionable_group.name] }

        expect(response.status).to eq(429)
      end
    end
  end
end
