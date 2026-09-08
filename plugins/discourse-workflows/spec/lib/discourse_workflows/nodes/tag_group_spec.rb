# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TagGroup::V1 do
  fab!(:admin)
  fab!(:tag) { Fabricate(:tag, name: "existing") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Workflow tags", tags: [tag]) }

  before { SiteSetting.tagging_enabled = true }

  describe "#execute" do
    let(:item) { { "json" => {} } }
    let(:history_scope) { UserHistory.where(action: UserHistory.actions[:tag_group_change]) }

    it "adds multiple tags, creates missing tags, and records the effective change" do
      previous_value = TagGroupSerializer.new(tag_group).to_json(root: false)
      config = {
        "tag_group_id" => tag_group.id,
        "tag_names" => "zulu tag, alpha",
        "actor_username" => admin.username,
      }

      expect { @result = execute_node(configuration: config, item: item) }.to change {
        history_scope.count
      }.by(1)

      expect(@result).to eq(
        "tag_group_id" => tag_group.id,
        "tag_group_name" => tag_group.name,
        "tag_names" => %w[alpha existing zulu-tag],
      )
      expect(tag_group.reload.base_tags.order(:name).pluck(:name)).to eq(
        %w[alpha existing zulu-tag],
      )

      history = history_scope.last
      expect(history).to have_attributes(
        acting_user_id: admin.id,
        subject: tag_group.name,
        previous_value: previous_value,
        new_value: TagGroupSerializer.new(tag_group).to_json(root: false),
      )
    end

    it "removes tags without deleting them and records the effective change" do
      removed_tag = Fabricate(:tag, name: "remove-me")
      tag_group.tags << removed_tag
      config = {
        "operation" => "remove",
        "tag_group_id" => tag_group.id,
        "tag_names" => "remove-me, absent",
        "actor_username" => admin.username,
      }

      expect { @result = execute_node(configuration: config, item: item) }.to change {
        history_scope.count
      }.by(1)

      expect(@result["tag_names"]).to eq(["existing"])
      expect(tag_group.reload.base_tags).to contain_exactly(tag)
      expect(Tag.find_by(id: removed_tag.id)).to eq(removed_tag)
    end

    it "does not record changes for duplicate additions or absent removals" do
      add_config = {
        "operation" => "add",
        "tag_group_id" => tag_group.id,
        "tag_names" => tag.name,
        "actor_username" => admin.username,
      }
      remove_config = add_config.merge("operation" => "remove", "tag_names" => "absent")

      expect {
        add_result = execute_node(configuration: add_config, item: item)
        remove_result = execute_node(configuration: remove_config, item: item)

        expect(add_result["tag_names"]).to eq([tag.name])
        expect(remove_result["tag_names"]).to eq([tag.name])
      }.not_to change { history_scope.count }
    end

    it "resolves expressions independently for each input item" do
      other_tag_group = Fabricate(:tag_group, name: "Other workflow tags")
      input_items = [
        { "json" => { "tag_group_id" => tag_group.id, "tag_names" => %w[first second] } },
        { "json" => { "tag_group_id" => other_tag_group.id, "tag_names" => ["third"] } },
      ]
      config = {
        "tag_group_id" => "={{ $json.tag_group_id }}",
        "tag_names" => "={{ $json.tag_names }}",
      }

      result = execute_node_output(configuration: config, input_items: input_items).first

      expect(result.map { |output| output["json"] }).to eq(
        [
          {
            "tag_group_id" => tag_group.id,
            "tag_group_name" => tag_group.name,
            "tag_names" => %w[existing first second],
          },
          {
            "tag_group_id" => other_tag_group.id,
            "tag_group_name" => other_tag_group.name,
            "tag_names" => %w[third],
          },
        ],
      )
    end

    it "uses canonical tag membership for synonyms" do
      synonym = Fabricate(:tag, name: "alias", target_tag: tag)
      other_tag_group = Fabricate(:tag_group, name: "Synonym workflow tags")
      add_config = {
        "operation" => "add",
        "tag_group_id" => other_tag_group.id,
        "tag_names" => synonym.name,
      }

      add_result = execute_node(configuration: add_config, item: item)

      expect(add_result["tag_names"]).to eq([tag.name])
      expect(other_tag_group.reload.tags).to contain_exactly(tag, synonym)

      remove_result =
        execute_node(configuration: add_config.merge("operation" => "remove"), item: item)

      expect(remove_result["tag_names"]).to be_empty
      expect(other_tag_group.reload.tags).to be_empty
    end

    it "does not add the tag group's parent tag as a member" do
      parent_tag = Fabricate(:tag, name: "parent")
      tag_group.update!(parent_tag: parent_tag)
      config = {
        "tag_group_id" => tag_group.id,
        "tag_names" => parent_tag.name,
        "actor_username" => admin.username,
      }

      expect { @result = execute_node(configuration: config, item: item) }.not_to change {
        history_scope.count
      }

      expect(@result["tag_names"]).to eq([tag.name])
      expect(tag_group.reload.tags).to contain_exactly(tag)
    end

    it "raises when no tag names are provided" do
      config = { "tag_group_id" => tag_group.id, "tag_names" => "" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "No tag names provided.",
      )
    end

    it "rejects invalid tags without changing the group or audit log" do
      config = {
        "tag_group_id" => tag_group.id,
        "tag_names" => "valid-tag, none",
        "actor_username" => admin.username,
      }

      expect {
        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /Tag group operation failed:/,
        )
      }.not_to change { history_scope.count }
      expect(tag_group.reload.base_tags).to contain_exactly(tag)
      expect(Tag.find_by_name("valid-tag")).to be_nil
    end

    it "raises when the tag group does not exist" do
      config = { "tag_group_id" => -1, "tag_names" => "anything" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "prevents a regular user from changing tag groups" do
      user = Fabricate(:user)
      config = {
        "tag_group_id" => tag_group.id,
        "tag_names" => "new-tag",
        "actor_username" => user.username,
      }

      expect {
        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
      }.not_to change { history_scope.count }
      expect(tag_group.reload.base_tags).to contain_exactly(tag)
    end

    it "prevents changes when tagging is disabled" do
      SiteSetting.tagging_enabled = false
      config = {
        "tag_group_id" => tag_group.id,
        "tag_names" => "new-tag",
        "actor_username" => admin.username,
      }

      expect {
        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
      }.not_to change { history_scope.count }
      expect(tag_group.reload.base_tags).to contain_exactly(tag)
    end
  end
end
