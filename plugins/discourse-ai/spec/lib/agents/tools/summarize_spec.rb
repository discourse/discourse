#frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::Summarize do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  let(:summary) { "summary stuff" }

  describe "#process" do
    it "streams section summaries and their combined summary" do
      post = Fabricate(:post, raw: "evidence " * 3200)
      responses =
        [["First ", "section"], ["Second ", "section"], ["Combined ", "summary"]].map do |deltas|
          body =
            deltas
              .map { |delta| "data: #{{ choices: [{ delta: { content: delta } }] }.to_json}\n\n" }
              .join
          { status: 200, body: body + "data: [DONE]\n\n" }
        end
      request =
        stub_request(:post, llm_model.url)
          .with { |req| JSON.parse(req.body)["stream"] == true }
          .to_return(*responses)
      summarization =
        described_class.new(
          { topic_id: post.topic_id, guidance: "What happened?" },
          bot_user: bot_user,
          llm: llm,
        )

      info = summarization.invoke(&progress_blk)

      expect(info).to eq("Topic summarized")
      expect(summarization.custom_raw).to eq("Combined summary")
      expect(request).to have_been_requested.times(3)
      expect(WebMock).to have_requested(:post, llm_model.url)
        .with { |req|
          JSON.parse(req.body)["messages"].last["content"].include?("First section\nSecond section")
        }
        .once
    end

    it "can generate correct info" do
      post = Fabricate(:post)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new(
            { topic_id: post.topic_id, guidance: "why did it happen?" },
            bot_user: bot_user,
            llm: llm,
          )
        info = summarization.invoke(&progress_blk)

        expect(info).to include("Topic summarized")
        expect(summarization.custom_raw).to include(summary)
        expect(summarization.chain_next_response?).to eq(false)
      end
    end

    it "combines streamed text blocks without including reasoning" do
      post = Fabricate(:post)

      thinking = DiscourseAi::Completions::Thinking.new(message: "Private reasoning")
      DiscourseAi::Completions::Llm.with_prepared_responses([[thinking, "summary ", "stuff"]]) do
        summarization =
          described_class.new(
            { topic_id: post.topic_id, guidance: "why did it happen?" },
            bot_user: bot_user,
            llm: llm,
          )
        summarization.invoke(&progress_blk)

        expect(summarization.custom_raw).to eq("summary stuff")
      end
    end

    it "protects hidden data" do
      category = Fabricate(:category)
      category.set_permissions({})
      category.save!

      topic = Fabricate(:topic, category_id: category.id)
      post = Fabricate(:post, topic: topic)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new(
            { topic_id: post.topic_id, guidance: "why did it happen?" },
            bot_user: bot_user,
            llm: llm,
          )
        info = summarization.invoke(&progress_blk)

        expect(info).not_to include(post.raw)

        expect(summarization.custom_raw).to eq(I18n.t("discourse_ai.ai_bot.topic_not_found"))
      end
    end
  end
end
