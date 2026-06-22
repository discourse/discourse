# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Topic::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:tag)

  before { SiteSetting.tagging_enabled = true }

  describe ".load_options_context" do
    fab!(:topic_with_custom_fields) { Fabricate(:topic, category: category) }
    fab!(:other_topic_with_custom_fields) { Fabricate(:topic, category: category) }

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "topic_custom_fields",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    before do
      topic_with_custom_fields.custom_fields["workflow_key"] = "first"
      topic_with_custom_fields.save_custom_fields
      other_topic_with_custom_fields.custom_fields["workflow_key"] = "second"
      other_topic_with_custom_fields.custom_fields["other_key"] = "other"
      other_topic_with_custom_fields.save_custom_fields
    end

    it "returns distinct topic custom field names for the chooser" do
      expect(load_options).to contain_exactly(
        { id: "other_key", name: "other_key" },
        { id: "workflow_key", name: "workflow_key" },
      )
    end

    it "filters topic custom field names by the filter term" do
      expect(load_options(filter: "workflow")).to contain_exactly(
        { id: "workflow_key", name: "workflow_key" },
      )
    end

    it "limits topic custom field names returned to the chooser" do
      101.times do |index|
        TopicCustomField.create!(
          topic: topic_with_custom_fields,
          name: "workflow_key_#{index}",
          value: "value",
        )
      end

      expect(load_options.length).to eq(described_class::CUSTOM_FIELD_OPTIONS_LIMIT)
    end
  end

  describe "#execute" do
    let(:item) { { "json" => {} } }

    def custom_field_entries(*rows)
      { "values" => rows }
    end

    context "with operation 'create'" do
      it "creates a topic for the configured actor" do
        result = nil

        expect do
          result =
            execute_node(
              configuration: {
                "operation" => "create",
                "title" => "Workflow topic",
                "raw" => "First post body",
                "category_id" => category.id.to_s,
                "actor_username" => admin.username,
              },
              item: item,
            )
        end.to change(Topic, :count).by(1).and change(Post, :count).by(1)

        topic = Topic.last

        expect(topic.title).to eq("Workflow topic")
        expect(topic.first_post.raw).to eq("First post body")
        expect(topic.category_id).to eq(category.id)
        expect(topic.user_id).to eq(admin.id)

        expect(result["topic"]).to include(
          "id" => topic.id,
          "title" => topic.title,
          "category_id" => category.id,
          "archetype" => Archetype.default,
        )
        expect(result["topic"]["last_poster_username"]).to eq(admin.username)
        expect(result["topic"]["posters"].map { |poster| poster["user_id"] }).to include(admin.id)
        expect(result).to include("post_id" => topic.first_post.id, "post_number" => 1)
        expect(result.dig("post", "id")).to eq(topic.first_post.id)
        expect(result.dig("post", "trust_level")).to eq(admin.trust_level)
      end

      it "creates a topic as the system user when actor_username is 'system'" do
        execute_node(
          configuration: {
            "operation" => "create",
            "title" => "System topic",
            "raw" => "Created by workflows",
            "actor_username" => "system",
          },
          item: item,
        )

        expect(Topic.last.user_id).to eq(Discourse.system_user.id)
      end

      it "does not create a topic as the anonymous actor" do
        expect do
          execute_node(
            configuration: {
              "operation" => "create",
              "title" => "Anonymous topic",
              "raw" => "Created by workflows",
              "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
            },
            item: item,
          )
        end.to raise_error(DiscourseWorkflows::NodeError).and not_change(Topic, :count)
      end

      it "accepts tags from an array" do
        execute_node(
          configuration: {
            "operation" => "create",
            "title" => "Tagged topic",
            "raw" => "With tags",
            "tag_names" => ["alpha", " beta "],
            "actor_username" => "system",
          },
          item: item,
        )

        expect(Topic.last.tags.pluck(:name)).to contain_exactly("alpha", "beta")
      end

      it "raises when the user cannot be found" do
        expect do
          execute_node(
            configuration: {
              "operation" => "create",
              "title" => "Workflow topic",
              "raw" => "First post body",
              "actor_username" => "nonexistent_user",
            },
            item: item,
          )
        end.to raise_error(DiscourseWorkflows::NodeError, "User 'nonexistent_user' not found")
      end

      it "raises when topic creation fails validation" do
        expect do
          execute_node(
            configuration: {
              "operation" => "create",
              "title" => "",
              "raw" => "",
              "actor_username" => "system",
            },
            item: item,
          )
        end.to raise_error(DiscourseWorkflows::NodeError)
      end
    end

    context "with operation 'get'" do
      fab!(:topic) { Fabricate(:topic, category: category, user: user) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "This is the topic body") }

      it "returns all expected topic and first post fields" do
        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => topic.id.to_s,
            },
            item: {
              "json" => {
                "topic_id" => topic.id.to_s,
              },
            },
          )

        expect(result["topic"]["id"]).to eq(topic.id)
        expect(result["topic"]["title"]).to eq(topic.title)
        expect(result["topic"]["category_id"]).to eq(category.id)
        expect(result["topic"]["tags"]).to eq([])
        expect(result["post"]).to include(
          "id" => topic.first_post.id,
          "topic_id" => topic.id,
          "user_id" => user.id,
          "username" => user.username,
          "trust_level" => user.trust_level,
          "post_url" => topic.first_post.url,
        )
      end

      it "returns tag names when topic has tags" do
        topic.tags << tag

        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => topic.id.to_s,
            },
            item: {
              "json" => {
                "topic_id" => topic.id.to_s,
              },
            },
          )

        expect(result["topic"]["tags"].map { |topic_tag| topic_tag["name"] }).to contain_exactly(
          tag.name,
        )
      end

      it "returns selected custom fields when requested" do
        topic.custom_fields["workflow_key"] = "workflow value"
        topic.custom_fields["other_key"] = "other value"
        topic.save_custom_fields

        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => topic.id.to_s,
              "custom_field_names" => ["workflow_key"],
            },
            item: {
              "json" => {
                "topic_id" => topic.id.to_s,
              },
            },
          )

        expect(result["topic"]["custom_fields"]).to eq("workflow_key" => "workflow value")
      end

      it "omits custom fields by default" do
        topic.custom_fields["workflow_key"] = "workflow value"
        topic.save_custom_fields

        result =
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => topic.id.to_s,
            },
            item: {
              "json" => {
                "topic_id" => topic.id.to_s,
              },
            },
          )

        expect(result["topic"]).not_to have_key("custom_fields")
      end

      it "raises when topic is not found" do
        expect do
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => "-1",
            },
            item: {
              "json" => {
              },
            },
          )
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises when actor_username cannot see the topic" do
        pm = Fabricate(:private_message_topic)

        expect do
          execute_node(
            configuration: {
              "operation" => "get",
              "topic_id" => pm.id.to_s,
              "actor_username" => user.username,
            },
            item: {
              "json" => {
                "topic_id" => pm.id.to_s,
              },
            },
          )
        end.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "with operation 'archive'" do
      fab!(:topic) { Fabricate(:topic, category: category, user: user) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user) }

      it "archives the topic for the configured actor" do
        result =
          execute_node(
            configuration: {
              "operation" => "archive",
              "topic_id" => topic.id.to_s,
              "actor_username" => admin.username,
            },
            item: item,
          )

        expect(topic.reload).to be_archived
        expect(result["topic"]).to include("id" => topic.id, "archived" => true)
        expect(result.dig("post", "id")).to eq(topic.first_post.id)
      end

      it "raises when the actor cannot archive the topic" do
        expect do
          execute_node(
            configuration: {
              "operation" => "archive",
              "topic_id" => topic.id.to_s,
              "actor_username" => user.username,
            },
            item: item,
          )
        end.to raise_error(Discourse::InvalidAccess)

        expect(topic.reload).not_to be_archived
      end
    end

    context "with operation 'list'" do
      fab!(:topic_1, :topic) do
        Fabricate(:topic, category: category, user: user, title: "First topic about workflows")
      end
      fab!(:post_1) { Fabricate(:post, topic: topic_1, user: user) }
      fab!(:topic_2, :topic) do
        Fabricate(:topic, category: category, user: user, title: "Second topic about workflows")
      end
      fab!(:post_2) { Fabricate(:post, topic: topic_2, user: user) }

      def execute_list(configuration:)
        execute_node_output(configuration: configuration).first
      end

      it "returns topics matching the query" do
        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
              "limit" => "10",
            },
          )

        expect(result.length).to eq(2)
        expect(result.map { |r| r["json"]["topic"]["id"] }).to contain_exactly(
          topic_1.id,
          topic_2.id,
        )
      end

      it "returns topics when query is not provided" do
        result = execute_list(configuration: { "operation" => "list", "limit" => "10" })

        expect(result.map { |output_item| output_item["json"]["topic"]["id"] }).to include(
          topic_1.id,
          topic_2.id,
        )
      end

      it "lists only publicly visible topics as the anonymous actor" do
        group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: group)
        private_topic = Fabricate(:topic, category: private_category, user: admin)
        Fabricate(:post, topic: private_topic, user: admin)

        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "limit" => "50",
              "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
            },
          )

        ids = result.map { |output_item| output_item["json"]["topic"]["id"] }
        expect(ids).to include(topic_1.id, topic_2.id)
        expect(ids).not_to include(private_topic.id)
      end

      it "respects the limit parameter" do
        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
              "limit" => "1",
            },
          )

        expect(result.length).to eq(1)
      end

      it "respects the offset parameter" do
        unoffset_result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
              "limit" => "2",
            },
          )
        offset_result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
              "limit" => "1",
              "offset" => "1",
            },
          )

        expect(offset_result.map { |output_item| output_item["json"]["topic"]["id"] }).to eq(
          [unoffset_result[1]["json"]["topic"]["id"]],
        )
      end

      it "defaults limit to 30 when not provided" do
        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
            },
          )

        expect(result.length).to eq(2)
      end

      it "returns expected fields for each topic" do
        topic_1.tags << tag

        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{category.slug}",
              "limit" => "10",
            },
          )

        topic_entry = result.find { |r| r["json"]["topic"]["id"] == topic_1.id }.dig("json")
        topic_data = topic_entry["topic"]
        post_data = topic_entry["post"]
        expect(topic_data).to include(
          "title" => topic_1.title,
          "category_id" => category.id,
          "closed" => false,
          "visible" => true,
        )
        expect(topic_data["tags"].map { |topic_tag| topic_tag["name"] }).to contain_exactly(
          tag.name,
        )
        expect(topic_data["posts_count"]).to be_present
        expect(topic_data["views"]).to be_present
        expect(topic_data["like_count"]).to be_present
        expect(topic_data["created_at"]).to be_present
        expect(topic_data["bumped_at"]).to be_present
        expect(post_data).to include(
          "id" => topic_1.first_post.id,
          "topic_id" => topic_1.id,
          "trust_level" => user.trust_level,
        )
      end

      it "preloads selected custom fields when requested" do
        topic_1.custom_fields["workflow_key"] = "first"
        topic_1.custom_fields["other_key"] = "ignored"
        topic_1.save_custom_fields
        topic_2.custom_fields["workflow_key"] = "second"
        topic_2.custom_fields["other_key"] = "ignored"
        topic_2.save_custom_fields

        custom_field_queries =
          track_sql_queries do
            result =
              execute_list(
                configuration: {
                  "operation" => "list",
                  "query" => "category:#{category.slug}",
                  "limit" => "10",
                  "custom_field_names" => ["workflow_key"],
                },
              )

            custom_fields =
              result.map { |output_item| output_item.dig("json", "topic", "custom_fields") }
            expect(custom_fields).to include(
              include("workflow_key" => "first"),
              include("workflow_key" => "second"),
            )
            custom_fields.each { |fields| expect(fields).not_to include("other_key") }
          end.select do |query|
            query.include?("topic_custom_fields") && query.include?("workflow_key")
          end

        expect(custom_field_queries.count).to eq(1)
        expect(custom_field_queries.first).to include("topic_id in")
        expect(custom_field_queries.first).to include("name in")
      end

      it "returns empty array when no topics match" do
        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{other_category.slug}",
              "limit" => "10",
            },
          )

        expect(result).to eq([])
      end

      it "clamps limit to 100" do
        captured_opts = nil
        original_new = TopicQuery.method(:new)
        allow(TopicQuery).to receive(:new).and_wrap_original do |_method, *args|
          captured_opts = args[1]
          original_new.call(*args)
        end

        execute_list(
          configuration: {
            "operation" => "list",
            "query" => "category:#{category.slug}",
            "limit" => "200",
          },
        )

        expect(captured_opts[:per_page]).to eq(100)
      end

      it "defaults to system user for topic queries" do
        restricted = Fabricate(:category, read_restricted: true)
        Fabricate(:category_group, category: restricted, group: Group[:staff], permission_type: 0)
        Fabricate(:topic, category: restricted)

        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{restricted.slug}",
            },
          )

        expect(result.length).to eq(1)
      end

      it "uses actor_username when set" do
        restricted = Fabricate(:category, read_restricted: true)
        Fabricate(:category_group, category: restricted, group: Group[:staff], permission_type: 0)
        Fabricate(:topic, category: restricted)

        result =
          execute_list(
            configuration: {
              "operation" => "list",
              "query" => "category:#{restricted.slug}",
              "actor_username" => other_user.username,
            },
          )

        expect(result.length).to eq(0)
      end
    end

    context "with operation 'close'" do
      fab!(:topic) { Fabricate(:topic, category: category, user: user) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user) }

      it "closes the topic as the configured actor" do
        result =
          execute_node(
            configuration: {
              "operation" => "close",
              "topic_id" => topic.id.to_s,
              "actor_username" => admin.username,
            },
            item: item,
          )

        expect(topic.reload).to be_closed
        expect(result["topic"]).to include("id" => topic.id, "closed" => true)
      end

      it "raises when actor_username cannot close the topic" do
        expect do
          execute_node(
            configuration: {
              "operation" => "close",
              "topic_id" => topic.id.to_s,
              "actor_username" => user.username,
            },
            item: item,
          )
        end.to raise_error(Discourse::InvalidAccess)

        expect(topic.reload).not_to be_closed
      end

      it "raises when closing as the anonymous actor" do
        expect do
          execute_node(
            configuration: {
              "operation" => "close",
              "topic_id" => topic.id.to_s,
              "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
            },
            item: item,
          )
        end.to raise_error(Discourse::InvalidAccess)

        expect(topic.reload).not_to be_closed
      end
    end

    context "with operation 'set_custom_fields'" do
      fab!(:topic) { Fabricate(:topic, category: category, user: user) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user) }

      it "sets topic custom fields as the configured actor" do
        result =
          execute_node(
            configuration: {
              "operation" => "set_custom_fields",
              "topic_id" => topic.id.to_s,
              "custom_fields" =>
                custom_field_entries(
                  { "key" => "foo", "value" => "bar" },
                  { "key" => "answer", "value" => "42" },
                ),
              "actor_username" => admin.username,
            },
            item: item,
          )

        expect(topic.reload.custom_fields["foo"]).to eq("bar")
        expect(topic.custom_fields["answer"]).to eq("42")
        expect(result["topic"]["custom_fields"]).to eq("foo" => "bar", "answer" => "42")
      end

      it "resolves expressions in custom field values" do
        execute_node(
          configuration: {
            "operation" => "set_custom_fields",
            "topic_id" => topic.id.to_s,
            "custom_fields" =>
              custom_field_entries({ "key" => "foo", "value" => "={{ $json.value }}" }),
          },
          item: {
            "json" => {
              "value" => "dynamic value",
            },
          },
        )

        expect(topic.reload.custom_fields["foo"]).to eq("dynamic value")
      end

      it "raises when actor_username cannot edit the topic" do
        expect do
          execute_node(
            configuration: {
              "operation" => "set_custom_fields",
              "topic_id" => topic.id.to_s,
              "custom_fields" => custom_field_entries({ "key" => "foo", "value" => "bar" }),
              "actor_username" => other_user.username,
            },
            item: item,
          )
        end.to raise_error(Discourse::InvalidAccess)

        expect(topic.reload.custom_fields["foo"]).to be_nil
      end
    end
  end
end
