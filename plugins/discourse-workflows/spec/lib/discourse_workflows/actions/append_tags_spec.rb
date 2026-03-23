# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::AppendTags::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "existing") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:append_tags")
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    it "appends a new tag to the topic" do
      config = { "topic_id" => topic.id.to_s, "tag_names" => "new-tag" }

      result = action.execute_single({}, item: item, config: config)

      expect(result[:tag_names]).to contain_exactly("new-tag")
      expect(topic.reload.tags.pluck(:name)).to include("new-tag")
    end

    it "appends multiple comma-separated tags" do
      config = { "topic_id" => topic.id.to_s, "tag_names" => "alpha, beta, gamma" }

      result = action.execute_single({}, item: item, config: config)

      expect(result[:tag_names]).to contain_exactly("alpha", "beta", "gamma")
    end

    it "does not duplicate tags the topic already has" do
      topic.tags << tag

      config = { "topic_id" => topic.id.to_s, "tag_names" => "existing, fresh" }

      result = action.execute_single({}, item: item, config: config)

      expect(result[:tag_names]).to contain_exactly("existing", "fresh")
      expect(topic.reload.tags.pluck(:name)).to contain_exactly("existing", "fresh")
    end

    it "creates tags that do not exist" do
      config = { "topic_id" => topic.id.to_s, "tag_names" => "brand-new" }

      expect { action.execute_single({}, item: item, config: config) }.to change(Tag, :count).by(1)
    end

    it "raises when topic does not exist" do
      config = { "topic_id" => "-1", "tag_names" => "anything" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when no tag names are provided" do
      config = { "topic_id" => topic.id.to_s, "tag_names" => "" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        RuntimeError,
        "No tag names provided",
      )
    end
  end
end
