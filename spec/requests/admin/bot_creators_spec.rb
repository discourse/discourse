# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:creator, :admin)
  fab!(:moderator)
  fab!(:bot) { Fabricate(:user, id: -1300, username: "attributed_bot", approved_by_id: admin.id) }

  def creator_lookup_queries(queries)
    queries.select do |sql|
      sql.match?(/FROM\s+"?user_histories"?/i) &&
        sql.match?(/JOIN\s+"?users"?\s+(?:AS\s+)?"?(?:bot_creators|creators)"?\b/i)
    end
  end

  describe "#index" do
    it "attributes a bot to its audit actor using the actor's current username, not its approver" do
      StaffActionLogger.new(creator).log_bot_creation(bot)
      creator.update!(username: "RenamedCreator")
      sign_in(admin)

      get "/admin/users/list/bots.json", params: { filter: bot.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to contain_exactly(
        a_hash_including(
          "id" => bot.id,
          "bot_creator" => {
            "username" => creator.username,
            "avatar_template" => creator.avatar_template,
            "url" => "/admin/users/#{creator.id}/renamedcreator",
          },
        ),
      )
    end

    it "includes the subfolder and encodes the lowercase Unicode creator username" do
      SiteSetting.unicode_usernames = true
      creator.update!(username: "Élève")
      StaffActionLogger.new(creator).log_bot_creation(bot)
      set_subfolder "/forum"
      sign_in(admin)

      get "/admin/users/list/bots.json", params: { filter: bot.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body.first["bot_creator"]).to eq(
        "username" => creator.username,
        "avatar_template" => creator.avatar_template,
        "url" => "/forum/admin/users/#{creator.id}/%C3%A9l%C3%A8ve",
      )
    end

    it "omits attribution when no creation event is recorded, even when an approver exists" do
      sign_in(admin)

      get "/admin/users/list/bots.json", params: { filter: bot.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body.map { |user| user["id"] }).to eq([bot.id])
      expect(response.parsed_body.first).not_to have_key("bot_creator")
    end

    it "omits attribution when the first creator was deleted despite a later live actor" do
      StaffActionLogger.new(creator).log_bot_creation(bot)
      StaffActionLogger.new(admin).log_bot_creation(bot)
      creator.delete
      sign_in(admin)

      get "/admin/users/list/bots.json", params: { filter: bot.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body.map { |user| user["id"] }).to eq([bot.id])
      expect(response.parsed_body.first).not_to have_key("bot_creator")
    end

    it "lets moderators list bots without exposing attribution or querying creators" do
      StaffActionLogger.new(creator).log_bot_creation(bot)
      sign_in(moderator)

      queries =
        track_sql_queries { get "/admin/users/list/bots.json", params: { filter: bot.username } }

      expect(response.status).to eq(200)
      expect(response.parsed_body.map { |user| user["id"] }).to eq([bot.id])
      expect(response.parsed_body.first).not_to have_key("bot_creator")
      expect(creator_lookup_queries(queries)).to be_empty
    end

    it "keeps creator metadata and creator lookups off the other user tabs" do
      StaffActionLogger.new(creator).log_bot_creation(bot)
      sign_in(admin)

      %w[active new staff].each do |tab|
        queries = track_sql_queries { get "/admin/users/list/#{tab}.json" }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_present
        expect(response.parsed_body).to all(satisfy { |user| !user.key?("bot_creator") })
        expect(creator_lookup_queries(queries)).to be_empty
      end
    end

    it "loads creators once for one or many bots without lazy creator queries while serializing" do
      StaffActionLogger.new(creator).log_bot_creation(bot)
      sign_in(admin)
      get "/admin/users/list/bots.json", params: { filter: bot.username }

      queries_for_one =
        track_sql_queries { get "/admin/users/list/bots.json", params: { filter: bot.username } }
      expect(response.status).to eq(200)
      expect(response.parsed_body.first.dig("bot_creator", "username")).to eq(creator.username)

      bots = [bot]
      4.times do |index|
        additional_bot = Fabricate(:user, id: -1301 - index, username: "attributed_bot_#{index}")
        additional_creator = Fabricate(:admin)
        StaffActionLogger.new(additional_creator).log_bot_creation(additional_bot)
        bots << additional_bot
      end

      queries_for_many =
        track_sql_queries do
          get "/admin/users/list/bots.json", params: { filter: "attributed_bot" }
        end

      expect(response.status).to eq(200)
      expect(response.parsed_body.map { |user| user["id"] }).to match_array(bots.map(&:id))
      expect(response.parsed_body).to all(include("bot_creator" => a_hash_including("username")))
      expect(creator_lookup_queries(queries_for_one).size).to eq(1)
      expect(creator_lookup_queries(queries_for_many).size).to eq(1)
      expect(queries_for_many.count { |sql| sql.match?(/FROM\s+"?users"?\b/i) }).to eq(
        queries_for_one.count { |sql| sql.match?(/FROM\s+"?users"?\b/i) },
      )
    end
  end
end
