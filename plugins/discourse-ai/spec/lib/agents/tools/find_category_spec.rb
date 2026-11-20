# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::FindCategory do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "volunteers") }
  fab!(:public_category) { Fabricate(:category, name: "Volunteer news") }
  fab!(:private_category) { Fabricate(:private_category, name: "Volunteer coordination", group:) }

  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:context) { bot_context(admin, private_message: true) }

  include_context "with AI bot enabled"

  def bot_context(user, private_message:)
    DiscourseAi::Agents::BotContext.new(user:).tap { |ctx| ctx.private_message = private_message }
  end

  def tool(query, context: self.context)
    described_class.new({ query: }, bot_user:, llm:, context:)
  end

  def results(result)
    result[:rows].map { |row| result[:column_names].zip(row).to_h }
  end

  it "finds public and private categories with their access and contents" do
    Fabricate(:topic, category: private_category)
    Fabricate(:private_category, group:, parent_category: private_category, name: "Shifts")
    public_category.update!(slug: "news")

    rows = results(tool("volunteer").invoke)

    expect(rows.map { |row| row["name"] }).to eq(["Volunteer coordination", "Volunteer news"])
    expect(rows.first).to include(
      "id" => private_category.id,
      "url" => "#{Discourse.base_url_no_prefix}#{private_category.url}",
      "private" => true,
      "permissions" => "volunteers: create_reply_see",
      "topic_count" => 1,
      "subcategory_count" => 1,
    )
    expect(rows.second).to include(
      "private" => false,
      "permissions" => "everyone: create_reply_see",
    )
  end

  it "matches slugs and lists an exact name match first" do
    exact = Fabricate(:category, name: "Volunteer")

    rows = results(tool("Volunteer").invoke)
    expect(rows.first["id"]).to eq(exact.id)

    private_category.update!(slug: "board-room")
    expect(results(tool("board").invoke).map { |row| row["id"] }).to eq([private_category.id])
  end

  it "describes a category only administrators can see" do
    private_category.category_groups.destroy_all

    row = results(tool("coordination").invoke).first

    expect(row).to include("private" => true, "permissions" => "administrators only")
  end

  it "says when nothing matches" do
    result = tool("nonexistent").invoke

    expect(result[:rows]).to eq([])
    expect(result[:message]).to include("nonexistent")
  end

  it "treats the query as text rather than a pattern" do
    expect(tool("%").invoke[:rows]).to eq([])
  end

  context "when a moderator manages categories" do
    fab!(:moderator)

    let(:context) { bot_context(moderator, private_message: true) }

    before { SiteSetting.moderators_manage_categories = true }

    it "only finds categories they can see" do
      rows = results(tool("volunteer").invoke)

      expect(rows.map { |row| row["id"] }).to eq([public_category.id])
    end
  end

  describe ".available_for_context?" do
    it "is offered to category managers in private messages" do
      expect(described_class.available_for_context?(context)).to eq(true)
    end

    it "is not offered in public topics, where replies are public" do
      public_context = bot_context(admin, private_message: false)

      expect(described_class.available_for_context?(public_context)).to eq(false)
      expect(tool("volunteer", context: public_context).invoke[:status]).to eq("error")
    end

    it "is offered in direct messages but not in chat channels" do
      dm = Fabricate(:direct_message_channel, users: [admin, bot_user])
      channel = Fabricate(:chat_channel)

      dm_context = DiscourseAi::Agents::BotContext.new(user: admin, channel_id: dm.id)
      channel_context = DiscourseAi::Agents::BotContext.new(user: admin, channel_id: channel.id)

      expect(described_class.available_for_context?(dm_context)).to eq(true)
      expect(described_class.available_for_context?(channel_context)).to eq(false)
    end

    it "is not offered to people who don't manage categories" do
      user_context = bot_context(Fabricate(:user), private_message: true)

      expect(described_class.available_for_context?(user_context)).to eq(false)
      expect(tool("volunteer", context: user_context).invoke[:status]).to eq("error")
    end
  end
end
