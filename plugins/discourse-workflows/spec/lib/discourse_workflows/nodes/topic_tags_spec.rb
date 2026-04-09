# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTags::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "existing") }
  fab!(:tag_2) { Fabricate(:tag, name: "second") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:topic_tags")
    end
  end

  def execute_node(configuration:, item:, run_as_user: Discourse.system_user)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        run_as_user: run_as_user,
        resolver: resolver,
        configuration: configuration,
        configuration_schema: described_class.configuration_schema,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

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
        RuntimeError,
        "No tag names provided",
      )
    end

    context "with restricted tags" do
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

      it "prevents adding staff-only tags when run_as_user is a regular user" do
        config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "staff-only" }

        expect do
          execute_node(configuration: config, item: item, run_as_user: Fabricate(:user))
        end.to raise_error(RuntimeError)
        expect(topic.reload.tags.pluck(:name)).not_to include("staff-only")
      end

      it "allows adding staff-only tags when run_as_user is staff" do
        config = { "operation" => "add", "topic_id" => topic.id.to_s, "tag_names" => "staff-only" }

        result = execute_node(configuration: config, item: item, run_as_user: Fabricate(:admin))

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
