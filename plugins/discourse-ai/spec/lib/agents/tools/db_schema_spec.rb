# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::DbSchema do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def invoke(tables)
    described_class.new({ tables: tables }, bot_user: bot_user, llm: llm).invoke
  end

  describe "#invoke" do
    it "returns one column per line with table headers" do
      info = invoke("posts,topics")[:schema_info]

      expect(info).to match(/^TABLE posts$/)
      expect(info).to match(/^TABLE topics$/)
      expect(info).to match(/^  id integer, PK$/)
    end

    it "marks foreign-key columns using Discourse's curated map" do
      info = invoke("topic_tags,topics")[:schema_info]

      expect(info).to match(/^  topic_id integer, FK → topics/)
      expect(info).to match(/^  user_id integer, FK → users/)
      expect(info).to match(/^  last_post_user_id integer, FK → users/) # via *_user_id rule
    end

    it "does not invent FK targets for non-FK _id columns" do
      info = invoke("topics")[:schema_info]

      # Previous heuristic produced misleading targets like "FK → externals" / "FK → featured_user1s".
      # Now we only mark FKs the Discourse map actually knows about.
      expect(info).not_to include("FK → externals")
      expect(info).not_to include("FK → featured_user1s")
    end

    it "simplifies long postgres type names" do
      info = invoke("topics")[:schema_info]

      expect(info).to include("varchar")
      expect(info).to include("timestamp")
      expect(info).not_to include("character varying")
      expect(info).not_to include("timestamp without time zone")
    end

    it "marks nullable columns" do
      info = invoke("topics")[:schema_info]

      expect(info).to match(/^  deleted_at timestamp, null$/)
    end

    it "reports missing tables instead of silently dropping them" do
      info = invoke("topics,not_a_real_table")[:schema_info]

      expect(info).to include("TABLE topics")
      expect(info).to include("TABLES NOT FOUND: not_a_real_table")
    end

    it "returns the requested tables string" do
      expect(invoke("posts,topics")[:tables]).to eq("posts,topics")
    end
  end
end
