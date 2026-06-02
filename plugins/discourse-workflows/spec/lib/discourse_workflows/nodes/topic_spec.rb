# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Topic::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:tag)

  before { SiteSetting.tagging_enabled = true }

  describe "#execute" do
    let(:item) { { "json" => {} } }

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

      it "returns all expected topic fields" do
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

        topic_data = result.find { |r| r["json"]["topic"]["id"] == topic_1.id }.dig("json", "topic")
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
    end
  end
end
