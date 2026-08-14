# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ReadPost do
  fab!(:llm_model)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: <<~MARKDOWN) }
        I spoke to my aunt on video for nearly an hour.

        - We call most weeks
        - Her puppy stayed still on camera

        ```text
        preserve this code block
        ```
      MARKDOWN

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "returns one exact post with structured identity and verbatim Markdown" do
      result = build_tool(excerpt_query: "puppy stayed still").invoke

      expect(result).to include(
        status: "ok",
        post_id: post.id,
        topic_id: topic.id,
        post_number: post.post_number,
        username: post.username,
        topic_title: topic.title,
        url: post.full_url,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        public_version: post.public_version,
        locale: post.locale,
        content: post.raw,
        content_mode: "full",
        truncated: false,
        match_type: "exact_phrase",
        content_note: described_class::CONTENT_NOTE,
      )
      expect(result[:matched_terms]).to contain_exactly("puppy", "stayed", "still")
      expect(result[:original_tokens]).to eq(llm.tokenizer.size(post.raw))
      expect(result[:returned_tokens]).to eq(result[:original_tokens])
    end

    it "returns a public post after its author is deleted" do
      post.update_column(:user_id, nil)

      expect(build_tool.invoke).to include(status: "ok", post_id: post.id, username: nil)
    end

    it "treats a live reply in a deleted topic as not found for an admin" do
      admin = Fabricate(:admin)
      topic.trash!(admin)

      expect(build_tool(read_private: true, user: admin).invoke).to eq(
        status: "not_found",
        topic_id: topic.id,
        post_number: post.post_number,
      )
    end

    it "returns the same not-found result for missing and inaccessible posts" do
      hidden_post = Fabricate(:post, topic: topic, hidden: true)

      hidden_result =
        described_class.new(
          { topic_id: topic.id, post_number: hidden_post.post_number },
          bot_user: bot_user,
          llm: llm,
        ).invoke
      hidden_post.destroy!
      missing_result =
        described_class.new(
          { topic_id: topic.id, post_number: hidden_post.post_number },
          bot_user: bot_user,
          llm: llm,
        ).invoke

      expect(hidden_result).to eq(missing_result)
      expect(hidden_result).to eq(
        status: "not_found",
        topic_id: topic.id,
        post_number: hidden_post.post_number,
      )
    end

    it "allows an authorized originating user to read a hidden post when private reads are enabled" do
      hidden_post = Fabricate(:post, topic: topic, hidden: true)
      admin = Fabricate(:admin)

      result =
        build_tool(post_number: hidden_post.post_number, read_private: true, user: admin).invoke

      expect(result).to include(status: "ok", post_id: hidden_post.id, content: hidden_post.raw)
    end

    it "uses the originating user only when private reads are enabled" do
      category = Fabricate(:category_with_definition)
      group = Fabricate(:group)
      category.set_permissions(group => :readonly)
      category.save!
      private_topic = Fabricate(:topic, category: category)
      private_post = Fabricate(:post, topic: private_topic)
      user = Fabricate(:user)
      GroupUser.create!(group: group, user: user)

      without_private_access =
        build_tool(
          topic_id: private_topic.id,
          post_number: private_post.post_number,
          user: user,
        ).invoke
      without_user =
        build_tool(
          topic_id: private_topic.id,
          post_number: private_post.post_number,
          read_private: true,
        ).invoke
      with_private_access =
        build_tool(
          topic_id: private_topic.id,
          post_number: private_post.post_number,
          read_private: true,
          user: user,
        ).invoke

      expect(without_private_access[:status]).to eq("not_found")
      expect(without_user[:status]).to eq("not_found")
      expect(with_private_access).to include(
        status: "ok",
        post_id: private_post.id,
        content: private_post.raw,
      )
    end

    it "returns one query-centered excerpt for an oversized post" do
      raw = [
        "opening filler " * 700,
        "The decisive phrase says the puppy stayed perfectly still on camera.",
        "closing filler " * 700,
      ].join("\n\n")
      post.update!(raw: raw)

      result =
        build_tool(excerpt_query: "puppy stayed perfectly still", max_content_tokens: 500).invoke

      expect(result).to include(
        content_mode: "excerpt",
        truncated: true,
        match_type: "exact_phrase",
      )
      expect(result[:content]).to include("puppy stayed perfectly still")
      expect(result[:content]).to include("preceding content omitted", "following content omitted")
      expect(result[:returned_tokens]).to be <= 500
      expect(result[:original_tokens]).to be > result[:returned_tokens]
    end

    it "keeps a multiline Unicode phrase intact in an excerpt" do
      phrase = "İstanbul notes: don’t skip\nthe puppy on camera"
      raw = "İ" * 2_000 + "\n#{phrase}\n" + "tail filler " * 1_000
      post.update!(raw: raw)

      result =
        build_tool(
          excerpt_query: "İstanbul notes: don't skip the puppy on camera",
          max_content_tokens: 500,
        ).invoke

      expect(result).to include(content_mode: "excerpt", match_type: "exact_phrase")
      expect(result[:content]).to include(phrase)
      expect(result[:returned_tokens]).to be <= 500
    end

    it "matches query terms in unsegmented scripts" do
      raw = "前の内容" * 1_000 + "私は日本語を勉強しています。" + "後の内容" * 1_000
      post.update!(raw: raw)

      result = build_tool(excerpt_query: "日本語", max_content_tokens: 500).invoke

      expect(result).to include(content_mode: "excerpt", match_type: "exact_phrase")
      expect(result[:content]).to include("日本語")
    end

    it "returns head and tail without match metadata when no excerpt query is supplied" do
      post.update!(raw: "START\n#{"long filler " * 2_000}\nEND")

      result = build_tool(max_content_tokens: 500).invoke

      expect(result).to include(content_mode: "head_tail", truncated: true)
      expect(result[:content]).to include("START", "END")
      expect(result).not_to have_key(:match_type)
      expect(result).not_to have_key(:matched_terms)
    end

    it "returns bounded head and tail content when an oversized post has no query match" do
      raw = "START_BOUNDARY\n#{"middle filler " * 1_800}\nEND_BOUNDARY"
      post.update!(raw: raw)

      result = build_tool(excerpt_query: "absent zebras", max_content_tokens: 500).invoke

      expect(result).to include(
        content_mode: "head_tail",
        truncated: true,
        match_type: "none",
        matched_terms: [],
      )
      expect(result[:content]).to include("START_BOUNDARY", "content omitted", "END_BOUNDARY")
      expect(result[:returned_tokens]).to be <= 500
    end

    it "uses term density when the exact excerpt query is absent" do
      raw = [
        "puppy " * 500,
        "The aunt appeared on video while the puppy remained still on camera.",
        "camera " * 500,
      ].join("\n\n")
      post.update!(raw: raw)

      result = build_tool(excerpt_query: "aunt puppy video camera", max_content_tokens: 500).invoke

      expect(result).to include(content_mode: "excerpt", match_type: "terms")
      expect(result[:matched_terms]).to contain_exactly("aunt", "puppy", "video", "camera")
      expect(result[:content]).to include("aunt appeared on video")
      expect(result[:returned_tokens]).to be <= 500
    end

    it "falls back to the default content budget for unsupported limits" do
      post.update!(raw: "budget filler " * 800)

      result = build_tool(max_content_tokens: 123).invoke

      expect(result[:returned_tokens]).to be <= described_class::DEFAULT_CONTENT_TOKENS
      expect(result[:returned_tokens]).to be > described_class::CONTENT_TOKEN_LIMITS.first
    end
  end

  def build_tool(
    topic_id: topic.id,
    post_number: post.post_number,
    excerpt_query: nil,
    max_content_tokens: nil,
    read_private: false,
    user: nil
  )
    parameters = { topic_id: topic_id, post_number: post_number }
    parameters[:excerpt_query] = excerpt_query if excerpt_query
    parameters[:max_content_tokens] = max_content_tokens if max_content_tokens

    described_class.new(
      parameters,
      bot_user: bot_user,
      llm: llm,
      agent_options: {
        "read_private" => read_private,
      },
      context: DiscourseAi::Agents::BotContext.new(user: user),
    )
  end
end
