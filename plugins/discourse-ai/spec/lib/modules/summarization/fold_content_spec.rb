# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::FoldContent do
  subject(:summarizer) { DiscourseAi::Summarization.topic_summary(topic) }

  let!(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1, raw: "This is a text") }

  before do
    enable_current_plugin
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#summarize" do
    before do
      # Make sure each content fits in a single chunk.
      # 700 is the number of tokens reserved for the prompt.
      model_tokens =
        700 +
          DiscourseAi::Tokenizer::OpenAiTokenizer.size(
            "(1 #{post_1.user.username_lower} said: This is a text ",
          ) + 3

      llm_model.update!(max_prompt_tokens: model_tokens)
    end

    let(:summary) { "this is a summary" }

    fab!(:user)

    it "summarizes the content" do
      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do |spy|
          summarizer.summarize(user).tap { expect(spy.completions).to eq(1) }
        end

      expect(result.summarized_text).to eq(summary)
    end

    it "lets a forced-tool gist inspect delegated images before setting the summary" do
      upload =
        UploadCreator.new(
          file_from_fixtures(
            "1x1.jpg",
            "images",
            Rails.root.join("plugins/discourse-ai/spec/fixtures"),
          ),
          "gist.jpg",
        ).create_for(user.id)
      post_1.update_columns(
        user_id: user.id,
        raw: "#{"context " * 20}![image](#{upload.short_url})",
      )
      native_model = Fabricate(:llm_model, vision_enabled: true)
      delegated_model = Fabricate(:llm_model, vision_llm_model: native_model)
      gist_agent =
        AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::ShortSummarizer])
      gist_agent.update_column(:vision_enabled, true)
      AiAgent.agent_cache.flush!
      SiteSetting.ai_summary_gists_agent = gist_agent.id
      image_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "view_1",
          name: "view_image",
          parameters: {
            images: [upload.id.to_s],
            question: "What information in this image is relevant to the discussion?",
          },
        )
      summary_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "summary_1",
          name: "set_topic_summary",
          parameters: {
            summary: "Image-aware gist",
          },
        )

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [image_call, "The image contains relevant context.", summary_call],
        ) do |spy|
          DiscourseAi::Summarization
            .topic_gist(topic, locale: "en", llm_model: delegated_model)
            .summarize(user)
            .tap { expect(spy.completions).to eq(3) }
        end

      expect(result.summarized_text).to eq("Image-aware gist")
    end

    it "forces the gist result after an image-aware attempt omits the output tool" do
      upload =
        UploadCreator.new(
          file_from_fixtures(
            "1x1.jpg",
            "images",
            Rails.root.join("plugins/discourse-ai/spec/fixtures"),
          ),
          "fallback-gist.jpg",
        ).create_for(user.id)
      post_1.update_columns(
        user_id: user.id,
        raw: "#{"context " * 20}![image](#{upload.short_url})",
      )
      native_model = Fabricate(:llm_model, vision_enabled: true)
      delegated_model = Fabricate(:llm_model, vision_llm_model: native_model)
      custom_agent = Fabricate(:ai_agent, vision_enabled: true)
      SiteSetting.ai_summary_gists_agent = custom_agent.id
      summary_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "summary_1",
          name: "set_topic_summary",
          parameters: {
            summary: "Forced fallback gist",
          },
        )

      allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
        :generate,
      ).and_wrap_original do |original, *args, **kwargs, &block|
        result = original.call(*args, **kwargs, &block)
        kwargs[:execution_context]&.token_usage_tracker&.add_effective(
          request: 40_000,
          response: 30_000,
        )
        result
      end

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["Output without the required tool", summary_call],
        ) do |spy|
          DiscourseAi::Summarization
            .topic_gist(topic, locale: "en", llm_model: delegated_model)
            .summarize(user)
            .tap { expect(spy.completions).to eq(2) }
        end

      expect(result.summarized_text).to eq("Forced fallback gist")
    end

    it "forces the gist result immediately when the agent does not allow images" do
      upload =
        UploadCreator.new(
          file_from_fixtures(
            "1x1.jpg",
            "images",
            Rails.root.join("plugins/discourse-ai/spec/fixtures"),
          ),
          "policy-off-gist.jpg",
        ).create_for(user.id)
      post_1.update_columns(
        user_id: user.id,
        raw: "#{"context " * 20}![image](#{upload.short_url})",
      )
      native_model = Fabricate(:llm_model, vision_enabled: true)
      delegated_model = Fabricate(:llm_model, vision_llm_model: native_model)
      custom_agent = Fabricate(:ai_agent, vision_enabled: false)
      SiteSetting.ai_summary_gists_agent = custom_agent.id
      summary_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "summary_1",
          name: "set_topic_summary",
          parameters: {
            summary: "Policy-off gist",
          },
        )

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([summary_call]) do |spy|
          DiscourseAi::Summarization
            .topic_gist(topic, locale: "en", llm_model: delegated_model)
            .summarize(user)
            .tap { expect(spy.completions).to eq(1) }
        end

      expect(result.summarized_text).to eq("Policy-off gist")
    end

    it "captures a tool-backed topic gist without structured output" do
      custom_agent =
        Fabricate(:ai_agent, response_format: [{ "key" => "fragile", "type" => "string" }])
      SiteSetting.ai_summary_gists_agent = custom_agent.id
      gist_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "ja")
      expect(gist_summarizer.bot.agent.response_format).to be_nil
      expect(gist_summarizer.bot.returns_json?).to eq(false)
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_1",
          name: "set_topic_summary",
          parameters: {
            summary: "日本語の要約",
          },
        )

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
          gist_summarizer
            .summarize(user)
            .tap do
              expect(spy.completions).to eq(1)
              expect(spy.model_params[:response_format]).to be_nil
            end
        end

      expect(result).to have_attributes(summarized_text: "日本語の要約", locale: "ja")
    end

    it "does not persist a gist when the model omits the summary tool" do
      gist_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "ja")

      expect do
        DiscourseAi::Completions::Llm.with_prepared_responses(["plain text"]) do
          gist_summarizer.summarize(user)
        end
      end.to raise_error(DiscourseAi::Summarization::FoldContent::MissingToolOutput)

      expect(AiSummary.gist.where(target: topic, locale: "ja")).to be_empty
    end
  end

  describe "#existing_summary" do
    it "finds a gist stored under an equivalent regional locale" do
      existing_gist =
        Fabricate(
          :topic_ai_gist,
          target: topic,
          locale: "pt",
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      regional_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "pt_BR")

      expect(regional_summarizer.existing_summary).to eq(existing_gist)
    end

    it "finds a complete summary stored under an equivalent regional locale" do
      existing_summary =
        Fabricate(
          :ai_summary,
          target: topic,
          locale: "pt",
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      regional_summarizer = DiscourseAi::Summarization.topic_summary(topic, locale: "pt_BR")

      expect(regional_summarizer.existing_summary).to eq(existing_summary)
    end

    context "when a summary already exists" do
      fab!(:ai_summary) do
        Fabricate(
          :ai_summary,
          target: topic,
          locale: SiteSetting.default_locale,
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      end

      it "doesn't mark it as outdated" do
        expect(summarizer.existing_summary.outdated).to eq(false)
      end

      context "when it's outdated because there are new targets" do
        before { Fabricate(:post, topic: topic, post_number: 2, raw: "This is a text") }

        it "marks it as outdated" do
          expect(summarizer.existing_summary.outdated).to eq(true)
        end
      end

      context "when it's outdated because existing content changes" do
        it "marks it as outdated" do
          ai_summary.update!(updated_at: 20.minutes.ago)
          post_1.update!(last_version_at: 5.minutes.ago)

          expect(summarizer.existing_summary.outdated).to eq(true)
        end
      end
    end
  end

  describe "#truncate" do
    it "leaves content within the token limit untouched" do
      text = "用 [keyd](https://man.archlinux.org/man/extra/keyd/keyd.1.en) 改键"

      expect(summarizer.truncate({ text: text.dup })[:text]).to eq(text)
    end

    it "doesn't let the tokenizer rewrite content within the token limit" do
      llm_model.update!(tokenizer: "DiscourseAi::Tokenizer::AnthropicTokenizer")
      text = "改键，很好用。" * 100

      expect(summarizer.truncate({ text: text.dup })[:text]).to eq(text)
    end

    it "keeps the start and the end of longer content" do
      item = summarizer.truncate({ text: "start #{"a " * 1500}#{"b " * 1500}end" })

      expect(item[:text]).to start_with("start a")
      expect(item[:text]).to end_with("b end")
    end

    it "preserves grapheme clusters at the split point" do
      item = summarizer.truncate({ text: "#{"🧩" * 600}⚖️#{"a" * 600}" })

      expect(item[:text]).to include(" ⚖️a")
    end
  end
end
