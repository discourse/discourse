# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTags::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "existing") }
  fab!(:tag_2) { Fabricate(:tag, name: "second") }

  before { SiteSetting.tagging_enabled = true }

  describe "#execute" do
    let(:item) { { "json" => {} } }

    context "with add operation" do
      it "adds a new tag to the topic" do
        config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "new-tag" }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("new-tag")
        expect(topic.reload.tags.pluck(:name)).to include("new-tag")
      end

      it "adds multiple comma-separated tags" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "tag_names" => "alpha, beta, gamma",
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("alpha", "beta", "gamma")
      end

      it "normalizes tag arrays and comma-separated tag values" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "tag_names" => ["alpha, beta", " ", "gamma"],
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("alpha", "beta", "gamma")
      end

      it "does not duplicate tags the topic already has" do
        topic.tags << tag

        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "tag_names" => "existing, fresh",
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("existing", "fresh")
        expect(topic.reload.tags.pluck(:name)).to contain_exactly("existing", "fresh")
      end

      it "creates tags that do not exist" do
        config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "brand-new" }

        expect { execute_node(configuration: config, item: item) }.to change(Tag, :count).by(1)
      end

      it "defaults to add when no operation is specified" do
        config = { "topic_id" => topic.id.to_s, "tag_names" => "default-tag" }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("default-tag")
        expect(topic.reload.tags.pluck(:name)).to include("default-tag")
      end
    end

    context "with remove operation" do
      it "removes tags from the topic" do
        topic.tags << tag

        config = { "operation" => "remove", "topic_id" => topic.id.to_s, "tag_names" => "existing" }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("existing")
        expect(topic.reload.tags.pluck(:name)).to be_empty
      end

      it "removes multiple comma-separated tags" do
        topic.tags << [tag, tag_2]

        config = {
          "operation" => "remove",
          "topic_id" => topic.id.to_s,
          "tag_names" => "existing, second",
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("existing", "second")
        expect(topic.reload.tags).to be_empty
      end

      it "silently skips tags not present on the topic" do
        topic.tags << tag

        config = {
          "operation" => "remove",
          "topic_id" => topic.id.to_s,
          "tag_names" => "existing, nonexistent",
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to contain_exactly("existing")
        expect(topic.reload.tags).to be_empty
      end
    end

    it "raises when topic does not exist" do
      config = { "operation" => "add", "topic_id" => "-1", "tag_names" => "anything" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when no tag names are provided" do
      config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "No tag names provided.",
      )
    end

    context "with restricted tags" do
      fab!(:regular_user, :user)
      fab!(:admin)
      fab!(:staff_tag_group) do
        Fabricate(
          :tag_group,
          permissions: {
            "staff" => TagGroupPermission.permission_types[:full],
          },
        )
      end
      fab!(:staff_tag) do
        tag = Fabricate(:tag, name: "staff-only")
        staff_tag_group.tags << tag
        tag
      end

      it "prevents adding staff-only tags when actor_username is a regular user" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "tag_names" => "staff-only",
          "actor_username" => regular_user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
        )
        expect(topic.reload.tags.pluck(:name)).not_to include("staff-only")
      end

      it "allows adding staff-only tags when actor_username is staff" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "tag_names" => "staff-only",
          "actor_username" => admin.username,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["tag_names"]).to include("staff-only")
        expect(topic.reload.tags.pluck(:name)).to include("staff-only")
      end
    end

    context "with tag synonyms" do
      fab!(:target_tag) { Fabricate(:tag, name: "target") }
      fab!(:synonym_tag) { Fabricate(:tag, name: "synonym", target_tag: target_tag) }

      it "resolves tag synonyms when adding" do
        config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "synonym" }

        execute_node(configuration: config, item: item)

        expect(topic.reload.tags.pluck(:name)).to include("target")
      end
    end
  end
end
