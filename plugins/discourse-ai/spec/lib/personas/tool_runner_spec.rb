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
  fab!(:tag1) { Fabricate(:tag, name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, name: "tag2") }
  fab!(:category) { Fabricate(:category, name: "Test Category", slug: "test-category") }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:pm_topic, :private_message_topic)
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
      tool.update!(
        script:
          "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['tag1', 'tag2'] }); }",
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
      expect(result["topic"]["tags"]).to contain_exactly("tag1", "tag2")
      expect(topic.reload.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
    end

    it "can get a topic with tags and first_post_id" do
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
      old_tag = Fabricate(:tag, name: "old_tag")
      topic.tags << old_tag
      Fabricate(:tag, name: "new_tag")
      tool.update!(
        script:
          "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['new_tag'] }, { append: true }); }",
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
      tool.update!(
        script:
          "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['tag1'] }, { username: 'system' }); }",
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
      expect(result["topic"]["tags"]).to eq(["tag1"])
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

    it "can get a topic with category info" do
      tool.update!(script: <<~JS)
          function invoke(params) {
            const t = discourse.getTopic(params.topic_id);
            return {
              category_id: t.category_id,
              category_name: t.category_name,
              category_slug: t.category_slug
            };
          }
        JS
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
      expect(result["category_id"]).to eq(category.id)
      expect(result["category_name"]).to eq("Test Category")
      expect(result["category_slug"]).to eq("test-category")
    end

    it "can set category on a topic by slug" do
      new_category = Fabricate(:category, slug: "new-category")
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, { category: "new-category" });
          }
        JS
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
      expect(result["topic"]["category_id"]).to eq(new_category.id)
      expect(topic.reload.category_id).to eq(new_category.id)
    end

    it "can set category on a topic by ID" do
      new_category = Fabricate(:category)
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, { category: params.category_id });
          }
        JS
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
            category_id: new_category.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(result["topic"]["category_id"]).to eq(new_category.id)
      expect(topic.reload.category_id).to eq(new_category.id)
    end

    it "returns error when setting category on private message" do
      tool.update!(script: <<~JS)
          function invoke(params) {
            try {
              return discourse.editTopic(params.topic_id, { category: params.category_id });
            } catch(e) {
              return { error: e.message };
            }
          }
        JS
      runner =
        described_class.new(
          parameters: {
            topic_id: pm_topic.id,
            category_id: category.id,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["error"]).to include("private")
    end

    it "can unlist a topic" do
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, { visible: false });
          }
        JS
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
      expect(result["topic"]["visible"]).to eq(false)
      expect(topic.reload.visible).to eq(false)
      expect(topic.visibility_reason_id).to eq(Topic.visibility_reasons[:manually_unlisted])
    end

    it "can relist a topic" do
      topic.update!(visible: false)
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, { visible: true });
          }
        JS
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
      expect(result["topic"]["visible"]).to eq(true)
      expect(topic.reload.visible).to eq(true)
      expect(topic.visibility_reason_id).to eq(Topic.visibility_reasons[:manually_relisted])
    end

    it "editTopic throws error for non-existent topic" do
      tool.update!(script: <<~JS)
          function invoke(params) {
            try {
              return discourse.editTopic(999999, { tags: ['tag1'] });
            } catch(e) {
              return { thrown: true, message: e.message };
            }
          }
        JS
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke
      expect(result["thrown"]).to eq(true)
      expect(result["message"]).to include("not found")
    end

    it "can edit multiple topic properties at once" do
      new_category = Fabricate(:category, slug: "multi-edit")
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, {
              category: "multi-edit",
              tags: ['tag1', 'tag2'],
              visible: false
            });
          }
        JS
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
      expect(result["topic"]["category_id"]).to eq(new_category.id)
      expect(result["topic"]["tags"]).to contain_exactly("tag1", "tag2")
      expect(result["topic"]["visible"]).to eq(false)
      topic.reload
      expect(topic.category_id).to eq(new_category.id)
      expect(topic.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
      expect(topic.visible).to eq(false)
    end

    it "can set category on a topic by name" do
      new_category = Fabricate(:category, name: "New Category Name", slug: "different-slug")
      tool.update!(script: <<~JS)
          function invoke(params) {
            return discourse.editTopic(params.topic_id, { category: "New Category Name" });
          }
        JS
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
      expect(result["topic"]["category_id"]).to eq(new_category.id)
      expect(topic.reload.category_id).to eq(new_category.id)
    end

    it "returns error when user cannot move topic to category" do
      regular_user = Fabricate(:user)
      new_category = Fabricate(:category)
      new_category.set_permissions(staff: :full)
      new_category.save!
      tool.update!(script: <<~JS)
          function invoke(params) {
            try {
              return discourse.editTopic(params.topic_id, { category: params.category_id }, { username: params.username });
            } catch(e) {
              return { error: e.message };
            }
          }
        JS
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
            category_id: new_category.id,
            username: regular_user.username,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["error"]).to include("Permission denied")
    end

    it "returns error when user cannot toggle topic visibility" do
      regular_user = Fabricate(:user)
      tool.update!(script: <<~JS)
          function invoke(params) {
            try {
              return discourse.editTopic(params.topic_id, { visible: false }, { username: params.username });
            } catch(e) {
              return { error: e.message };
            }
          }
        JS
      runner =
        described_class.new(
          parameters: {
            topic_id: topic.id,
            username: regular_user.username,
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
        )
      result = runner.invoke
      expect(result["error"]).to include("Permission denied")
    end

    it "setTags alias works for backwards compatibility" do
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
  end
end
