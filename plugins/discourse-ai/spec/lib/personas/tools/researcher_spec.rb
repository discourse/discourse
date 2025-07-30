# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Researcher do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  fab!(:admin)
  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "research-category") }
  fab!(:tag_research) { Fabricate(:tag, name: "research") }
  fab!(:tag_data) { Fabricate(:tag, name: "data") }

  fab!(:topic_with_tags) { Fabricate(:topic, category: category, tags: [tag_research, tag_data]) }
  fab!(:post) { Fabricate(:post, topic: topic_with_tags) }
  fab!(:another_post) { Fabricate(:post) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  it "uses custom researcher_llm and applies token limits correctly" do
    # Create a second LLM model to test the researcher_llm option
    secondary_llm_model = Fabricate(:llm_model, name: "secondary_model")

    # Create test content with long text to test token truncation
    topic = Fabricate(:topic, category: category, tags: [tag_research])
    long_content = "zz " * 100 # This will exceed our token limit
    _test_post =
      Fabricate(:post, topic: topic, raw: long_content, user: user, skip_validation: true)

    prompts = nil
    responses = [["Research completed"]]
    researcher = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: secondary_llm_model,
    ) do |_, _, _prompts|
      researcher =
        described_class.new(
          { filter: "category:research-category", goals: "analyze test content", dry_run: false },
          persona_options: {
            "researcher_llm" => secondary_llm_model.id,
            "max_tokens_per_post" => 50, # Very small to force truncation
            "max_tokens_per_batch" => 8000,
          },
          bot_user: bot_user,
          llm: nil,
          context: DiscourseAi::Personas::BotContext.new(user: user, post: post),
        )

      results = researcher.invoke(&progress_blk)

      expect(results[:dry_run]).to eq(false)
      expect(results[:results]).to be_present

      prompts = _prompts
    end

    expect(prompts).to be_present

    user_message = prompts.first.messages.find { |m| m[:type] == :user }
    expect(user_message[:content]).to be_present

    # count how many times the the "zz " appears in the content (a bit of token magic, we lose a couple cause we redact)
    expect(user_message[:content].scan("zz ").count).to eq(48)
  end

  describe "#invoke" do
    it "can correctly filter to a topic id" do
      researcher =
        described_class.new(
          { dry_run: true, filter: "topic:#{topic_with_tags.id}", goals: "analyze topic content" },
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user, post: post),
        )
      results = researcher.invoke(&progress_blk)
      expect(results[:number_of_posts]).to eq(1)
    end

    it "returns filter information and result count" do
      researcher =
        described_class.new(
          { filter: "tag:research after:2023", goals: "analyze post patterns", dry_run: true },
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user, post: post),
        )

      results = researcher.invoke(&progress_blk)

      expect(results[:filter]).to eq("tag:research after:2023")
      expect(results[:goals]).to eq("analyze post patterns")
      expect(results[:dry_run]).to eq(true)
      expect(results[:number_of_posts]).to be > 0
      expect(researcher.filter).to eq("tag:research after:2023")
      expect(researcher.result_count).to be > 0
    end

    it "handles empty filters" do
      researcher =
        described_class.new({ goals: "analyze all content" }, bot_user: bot_user, llm: llm)

      results = researcher.invoke(&progress_blk)

      expect(results[:error]).to eq("No filter provided")
    end

    it "accepts max_results option" do
      researcher =
        described_class.new(
          { filter: "category:research-category" },
          persona_options: {
            "max_results" => "50",
          },
          bot_user: bot_user,
          llm: llm,
        )

      expect(researcher.options[:max_results]).to eq(50)
    end

    it "returns error for invalid filter fragments" do
      researcher =
        described_class.new(
          { filter: "invalidfilter tag:research", goals: "analyze content" },
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user, post: post),
        )

      results = researcher.invoke(&progress_blk)

      expect(results[:error]).to include("Invalid filter fragment")
    end

    it "returns correct results for non-dry-run with filtered posts" do
      # Stage 2 topics, each with 2 posts
      topics = Array.new(2) { Fabricate(:topic, category: category, tags: [tag_research]) }
      topics.flat_map do |topic|
        [
          Fabricate(:post, topic: topic, raw: "Relevant content 1", user: user),
          Fabricate(:post, topic: topic, raw: "Relevant content 2", user: admin),
        ]
      end

      # Filter to posts by user in research-category
      researcher =
        described_class.new(
          {
            filter: "category:research-category username:#{user.username}",
            goals: "find relevant content",
            dry_run: false,
          },
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user, post: post),
        )

      responses = 10.times.map { |i| ["Found: Relevant content #{i + 1}"] }
      results = nil

      last_progress = nil
      progress_blk = Proc.new { |response| last_progress = response }

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        researcher.llm = llm_model.to_llm
        results = researcher.invoke(&progress_blk)
      end

      expect(last_progress).to include("find relevant content")
      expect(last_progress).to include("category:research-category")

      expect(results[:dry_run]).to eq(false)
      expect(results[:goals]).to eq("find relevant content")
      expect(results[:filter]).to eq("category:research-category username:#{user.username}")
      expect(results[:results].first).to include("Found: Relevant content 1")
    end
  end
end
