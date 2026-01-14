# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Personas::ToolRunner do
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user, admin: true) }
  fab!(:tool) do
    AiTool.create!(
      name: "test_tool",
      tool_name: "test_tool",
      description: "a test tool",
      script: "function invoke(params) { return { result: 'ok' }; }",
      summary: "test",
      created_by: user,
    )
  end
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model.id) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
  end

  describe "#invoke" do
    it "can execute a simple script" do
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke
      expect(result).to eq({ "result" => "ok" })
    end

    it "exposes discourse.baseUrl" do
      tool.update!(script: "function invoke() { return { baseUrl: discourse.baseUrl }; }")
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke
      expect(result["baseUrl"]).to eq(Discourse.base_url)
    end

    it "can set tags on a topic" do
      topic = Fabricate(:topic)
      Fabricate(:tag, name: "tag1")
      Fabricate(:tag, name: "tag2")
      tool.update!(
        script:
          "function invoke(params) { return discourse.setTags(params.topic_id, ['tag1', 'tag2']); }",
      )
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(topic.reload.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
    end

    it "can get a topic with tags and first_post_id" do
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic)
      tag = Fabricate(:tag, name: "test_tag")
      topic.tags << tag
      tool.update!(
        script:
          "function invoke(params) { const t = discourse.getTopic(params.topic_id); return { tags: t.tags, first_post_id: t.first_post_id }; }",
      )
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["tags"]).to contain_exactly("test_tag")
      expect(result["first_post_id"]).to eq(topic.first_post.id)
    end

    it "can append tags on a topic" do
      topic = Fabricate(:topic)
      old_tag = Fabricate(:tag, name: "old_tag")
      topic.tags << old_tag
      Fabricate(:tag, name: "new_tag")
      tool.update!(
        script:
          "function invoke(params) { return discourse.setTags(params.topic_id, ['new_tag'], { append: true }); }",
      )
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(topic.reload.tags.pluck(:name)).to contain_exactly("old_tag", "new_tag")
    end

    it "can set tags as a specific user" do
      topic = Fabricate(:topic)
      Fabricate(:tag, name: "tag1")
      tool.update!(
        script:
          "function invoke(params) { return discourse.setTags(params.topic_id, ['tag1'], { username: 'system' }); }",
      )
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result).to eq({ "success" => true, "tags" => ["tag1"] })
      expect(topic.reload.tags.pluck(:name)).to contain_exactly("tag1")
    end

    it "can edit a post" do
      post = Fabricate(:post)
      tool.update!(
        script:
          "function invoke(params) { return discourse.editPost(params.post_id, 'new raw content', { edit_reason: 'AI edit' }); }",
      )
      runner =
        described_class.new(
          parameters: {
            post_id: post.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(post.reload.raw).to eq("new raw content")
      expect(post.edit_reason).to eq("AI edit")
      expect(post.last_editor_id).to eq(Discourse.system_user.id)
    end

    it "can edit a post as a specific user" do
      other_user = Fabricate(:user, admin: true)
      post = Fabricate(:post)
      tool.update!(
        script:
          "function invoke(params) { return discourse.editPost(params.post_id, 'new raw content', { username: '#{other_user.username}' }); }",
      )
      runner =
        described_class.new(
          parameters: {
            post_id: post.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(post.reload.last_editor_id).to eq(other_user.id)
    end

    it "can generate JSON from LLM" do
      tool.update!(script: "function invoke() { return llm.generate('test', { json: true }); }")

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ['{"key": "value"}'],
      ) do |_, _, _, prompt_options|
        runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
        result = runner.invoke
        expect(result).to eq({ "key" => "value" })

        expect(prompt_options.last[:response_format]).to eq({ "type" => "json_object" })
      end
    end
  end
end
