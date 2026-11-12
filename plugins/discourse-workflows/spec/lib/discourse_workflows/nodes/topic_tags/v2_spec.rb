# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTags::V2 do
  fab!(:topic)
  fab!(:existing_tag) { Fabricate(:tag, name: "existing") }
  fab!(:removed_tag) { Fabricate(:tag, name: "submitted") }
  fab!(:added_tag) { Fabricate(:tag, name: "scheduled") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags = [existing_tag, removed_tag]
  end

  describe "#execute" do
    it "uses existing tag names after the maximum tag length is reduced" do
      SiteSetting.max_tag_length = existing_tag.name.length
      config = {
        "topic_id" => topic.id,
        "add_tag_names" => added_tag.name.upcase,
        "remove_tag_names" => removed_tag.name.upcase,
      }

      execute_node(configuration: config)

      expect(topic.reload.tags).to contain_exactly(existing_tag, added_tag)
    end

    it "replaces mutually exclusive tags together, preserving unrelated tags" do
      Fabricate(:tag_group, tags: [removed_tag, added_tag], one_per_topic: true)
      config = {
        "topic_id" => topic.id,
        "add_tag_names" => added_tag.name,
        "remove_tag_names" => removed_tag.name,
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          @result = execute_node(configuration: config)
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, added_tag)
      expect(@result).to eq(
        "topic_id" => topic.id,
        "tag_names" => [existing_tag.name, added_tag.name],
      )
      expect(@result).to match_node_output_schema(described_class)
      expect(events).to contain_exactly(
        a_hash_including(
          params: [
            topic,
            {
              old_tag_names: contain_exactly(existing_tag.name, removed_tag.name),
              new_tag_names: contain_exactly(existing_tag.name, added_tag.name),
              user: Discourse.system_user,
            },
          ],
        ),
      )
    end

    it "resolves expressions and canonical tag names for each input item" do
      synonym = Fabricate(:tag, name: "alias", target_tag: removed_tag)
      other_topic = Fabricate(:topic, tags: [existing_tag, removed_tag])
      items = [
        { "json" => { "topic_id" => topic.id, "add" => ["new tag, another"], "remove" => [] } },
        {
          "json" => {
            "topic_id" => other_topic.id,
            "add" => [],
            "remove" => "#{synonym.name.upcase}, #{existing_tag.name.upcase}",
          },
        },
      ]
      config = {
        "topic_id" => "={{ $json.topic_id }}",
        "add_tag_names" => "={{ $json.add }}",
        "remove_tag_names" => "={{ $json.remove }}",
        "replace_tag_names" => "={{ globalThis.unusedTagsEvaluated = true }}",
        "actor_username" => "={{ globalThis.unusedTagsEvaluated ? '' : 'system' }}",
      }

      execute_node_output(configuration: config, input_items: items)

      expect(topic.reload.tags.pluck(:name)).to contain_exactly(
        existing_tag.name,
        removed_tag.name,
        "new-tag",
        "another",
      )
      expect(other_topic.reload.tags).to be_empty
    end

    it "replaces live tags with canonical expression results and ignores modify fields" do
      synonym = Fabricate(:tag, name: "alias", target_tag: added_tag)
      item = {
        "json" => {
          "tags" => [removed_tag.name],
          "replacement" => [synonym.name.upcase, added_tag.name],
        },
      }
      config = {
        "mode" => "replace",
        "topic_id" => topic.id,
        "replace_tag_names" => "={{ $json.replacement }}",
        "add_tag_names" => "={{ globalThis.unusedTagsEvaluated = true }}",
        "remove_tag_names" => "={{ globalThis.unusedTagsEvaluated = true }}",
        "actor_username" => "={{ globalThis.unusedTagsEvaluated ? '' : 'system' }}",
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          @result = execute_node(configuration: config, item: item)
        end

      expect(topic.reload.tags).to contain_exactly(added_tag)
      expect(@result).to eq("topic_id" => topic.id, "tag_names" => [added_tag.name])
      expect(events).to contain_exactly(
        a_hash_including(
          params: [
            topic,
            {
              old_tag_names: contain_exactly(existing_tag.name, removed_tag.name),
              new_tag_names: [added_tag.name],
              user: Discourse.system_user,
            },
          ],
        ),
      )
    end

    it "clears all tags with an empty replacement and leaves an already empty topic unchanged" do
      config = { "mode" => "replace", "topic_id" => topic.id, "replace_tag_names" => [] }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          @result = execute_node(configuration: config)
        end

      expect(topic.reload.tags).to be_empty
      expect(@result).to eq("topic_id" => topic.id, "tag_names" => [])
      expect(events.map { |event| event[:params].last[:new_tag_names] }).to eq([[]])

      expect(execute_node(configuration: config)).to eq(@result)
      expect(topic.reload.tags).to be_empty
    end

    it "rejects failed replacement expressions without changing tags or emitting events",
       :aggregate_failures do
      config = {
        "mode" => "replace",
        "topic_id" => topic.id,
        "replace_tag_names" => "={{ $json.missing.deep }}",
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty
    end

    it "rejects nonblank replacement names that normalize to empty" do
      config = { "mode" => "replace", "topic_id" => topic.id, "replace_tag_names" => ["..."] }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
            I18n.t("discourse_workflows.errors.topic_tags.unapplied_tag_names", tag_names: "..."),
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty
    end

    it "rejects native changes to the requested replacement without changing tags or emitting events" do
      category = Fabricate(:category, allow_global_tags: false, tags: [existing_tag, removed_tag])
      topic.update!(category: category)
      config = {
        "mode" => "replace",
        "topic_id" => topic.id,
        "replace_tag_names" => [existing_tag.name, added_tag.name],
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty

      category.update!(allow_global_tags: true)
      parent_tag = Fabricate(:tag)
      Fabricate(:tag_group, tags: [added_tag], parent_tag: parent_tag)
      config["replace_tag_names"] = [added_tag.name]

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty

      execute_node(configuration: { "topic_id" => topic.id, "add_tag_names" => added_tag.name })

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag, added_tag, parent_tag)
    end

    it "rejects tag names present in both lists after normalization" do
      SiteSetting.force_lowercase_tags = false
      synonym = Fabricate(:tag, name: "alias", target_tag: removed_tag)
      config = {
        "topic_id" => topic.id,
        "add_tag_names" => "#{synonym.name.upcase}, New tag",
        "remove_tag_names" => "#{removed_tag.name}, new-tag",
      }

      expect { execute_node(configuration: config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_workflows.errors.topic_tags.overlapping_tag_names",
          tag_names: "new-tag, #{removed_tag.name}",
        ),
      )
      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(Tag.find_by_name("new-tag")).to be_nil
    end

    it "requires nonempty modify input and a supported mode" do
      config = { "topic_id" => topic.id, "add_tag_names" => [" ", ","], "remove_tag_names" => "" }

      expect { execute_node(configuration: config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "No tag names provided.",
      )

      config = { "topic_id" => topic.id, "mode" => "unknown", "replace_tag_names" => [] }

      expect { execute_node(configuration: config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.topic_tags.unknown_mode", mode: config["mode"]),
      )
      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
    end

    it "rolls back all changes when the final tag set is invalid" do
      Fabricate(:tag_group, tags: [removed_tag, added_tag], one_per_topic: true)
      config = {
        "topic_id" => topic.id,
        "add_tag_names" => [added_tag.name, "new-tag"],
        "remove_tag_names" => existing_tag.name,
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
            /Tag operation failed:/,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(Tag.find_by_name("new-tag")).to be_nil
      expect(events).to be_empty
    end

    it "rejects changes exceeding the tag limit instead of dropping unrelated tags" do
      SiteSetting.max_tags_per_topic = 1
      config = { "topic_id" => topic.id, "add_tag_names" => added_tag.name }

      expect { execute_node(configuration: config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("tags.too_many_tags_for_topic", count: SiteSetting.max_tags_per_topic),
      )
      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
    end

    it "rejects partially applied tag changes without changing the topic or emitting events" do
      category = Fabricate(:category, allow_global_tags: false, tags: [existing_tag, removed_tag])
      topic.update!(category: category)
      config = {
        "topic_id" => topic.id,
        "add_tag_names" => added_tag.name,
        "remove_tag_names" => removed_tag.name,
      }

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty

      category.update!(allow_global_tags: true)
      Fabricate(:tag_group, tags: [removed_tag], parent_tag: existing_tag)
      config["remove_tag_names"] = existing_tag.name

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(
            DiscourseWorkflows::NodeError,
          )
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty
    end

    it "rejects actors who can use tags but cannot access the topic" do
      actor = Fabricate(:trust_level_1)
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
      topic.update!(category: Fabricate(:private_category, group: Group[:staff]))
      config = {
        "topic_id" => topic.id,
        "actor_username" => actor.username,
        "add_tag_names" => added_tag.name,
        "remove_tag_names" => removed_tag.name,
      }

      expect(actor.guardian.can_tag?(topic)).to eq(true)
      expect(actor.guardian.can_see_topic?(topic)).to eq(false)

      events =
        DiscourseEvent.track_events(:topic_tags_changed) do
          expect { execute_node(configuration: config) }.to raise_error(Discourse::InvalidAccess)
        end

      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
      expect(events).to be_empty
    end

    it "preserves all tags when the actor cannot add a restricted tag" do
      actor = Fabricate(:trust_level_1)
      topic.update!(user: actor)
      Fabricate(
        :tag_group,
        tags: [added_tag],
        permissions: {
          "staff" => TagGroupPermission.permission_types[:full],
        },
      )
      config = {
        "topic_id" => topic.id,
        "actor_username" => actor.username,
        "add_tag_names" => added_tag.name,
        "remove_tag_names" => removed_tag.name,
      }

      expect { execute_node(configuration: config) }.to raise_error(DiscourseWorkflows::NodeError)
      expect(topic.reload.tags).to contain_exactly(existing_tag, removed_tag)
    end

    it "requires the actor's permission to tag personal messages" do
      actor = Fabricate(:admin)
      personal_message = Fabricate(:private_message_topic)
      SiteSetting.pm_tags_allowed_for_groups = ""
      config = {
        "topic_id" => personal_message.id,
        "actor_username" => actor.username,
        "add_tag_names" => added_tag.name,
      }

      expect { execute_node(configuration: config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_workflows.errors.topic_tags.personal_message_not_allowed",
          username: actor.username,
        ),
      )
      expect(personal_message.reload.tags).to be_empty
    end
  end
end
