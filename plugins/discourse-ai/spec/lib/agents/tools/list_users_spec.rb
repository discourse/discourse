# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListUsers do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def column_value(row, result, column_name)
    row[result[:column_names].index(column_name)]
  end

  def usernames_from(result)
    username_column = result[:column_names].index("username")
    result[:rows].map { |row| row[username_column] }
  end

  def row_for(result, username)
    result[:rows].find { |row| column_value(row, result, "username") == username }
  end

  describe "#invoke" do
    it "lists users with safe account status fields" do
      eligible_user = Fabricate(:user, username: "seedable_alice")
      inactive_user = Fabricate(:inactive_user, username: "seedable_inactive")
      staged_user = Fabricate(:staged, username: "seedable_staged", active: true)
      suspended_user =
        Fabricate(:user, username: "seedable_suspended", suspended_till: 1.week.from_now)

      result =
        described_class.new({ query: "seedable", limit: 100 }, bot_user: bot_user, llm: llm).invoke
      usernames = usernames_from(result)

      expect(result[:column_names]).to contain_exactly(
        "id",
        "username",
        "name",
        "active",
        "staged",
        "suspended",
        "real",
      )
      expect(usernames).to include(
        eligible_user.username,
        inactive_user.username,
        staged_user.username,
        suspended_user.username,
      )
      expect(column_value(row_for(result, inactive_user.username), result, "active")).to eq(false)
      expect(column_value(row_for(result, staged_user.username), result, "staged")).to eq(true)
      expect(column_value(row_for(result, suspended_user.username), result, "suspended")).to eq(
        true,
      )
    end

    it "filters users by account status when requested" do
      eligible_user = Fabricate(:user, username: "filter_alice")
      inactive_user = Fabricate(:inactive_user, username: "filter_inactive")
      staged_user = Fabricate(:staged, username: "filter_staged", active: true)
      suspended_user =
        Fabricate(:user, username: "filter_suspended", suspended_till: 1.week.from_now)

      result =
        described_class.new(
          {
            query: "filter",
            real: true,
            active: true,
            staged: false,
            suspended: false,
            limit: 100,
          },
          bot_user: bot_user,
          llm: llm,
        ).invoke
      usernames = usernames_from(result)

      expect(usernames).to include(eligible_user.username)
      expect(usernames).not_to include(
        inactive_user.username,
        staged_user.username,
        suspended_user.username,
      )
    end

    it "filters users by group membership" do
      group = Fabricate(:group, name: "seeders")
      included_user = Fabricate(:user, username: "group_seed_in")
      excluded_user = Fabricate(:user, username: "group_seed_out")
      group.add(included_user)

      result =
        described_class.new(
          { query: "group_seed", groups: ["seeders"], limit: 20 },
          bot_user: bot_user,
          llm: llm,
        ).invoke

      expect(usernames_from(result)).to contain_exactly(included_user.username)
      expect(usernames_from(result)).not_to include(excluded_user.username)
    end

    it "filters users by topic creation permission in a category" do
      SiteSetting.create_topic_allowed_groups = Group::AUTO_GROUPS[:admins]

      category = Fabricate(:category)
      allowed_user = Fabricate(:admin, username: "cat_seed_admin")
      blocked_user = Fabricate(:user, username: "cat_seed_blocked")

      result =
        described_class.new(
          { query: "cat_seed", category_name: category.slug, limit: 20 },
          bot_user: bot_user,
          llm: llm,
        ).invoke

      expect(usernames_from(result)).to contain_exactly(allowed_user.username)
      expect(usernames_from(result)).not_to include(blocked_user.username)
    end
  end
end
