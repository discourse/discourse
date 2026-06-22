# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Post::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:tag) { Fabricate(:tag, name: "weekly-report") }

  before { SiteSetting.tagging_enabled = true }

  describe "#execute" do
    let(:item) { { "json" => {} } }

    it "creates a post for the configured author" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "create",
              "topic_id" => topic.id.to_s,
              "raw" => "Workflow reply",
              "author_username" => admin.username,
            },
            item: item,
          )
      end.to change { topic.posts.count }.by(1)

      reply = topic.posts.order(:id).last
      expect(reply.raw).to eq("Workflow reply")
      expect(reply.user_id).to eq(admin.id)
      expect(result["post"]).to include(
        "id" => reply.id,
        "topic_id" => topic.id,
        "topic_title" => topic.title,
        "post_number" => reply.post_number,
        "username" => admin.username,
        "raw" => "Workflow reply",
      )
    end

    it "raises when creating a post as the anonymous actor" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic

      expect do
        execute_node(
          configuration: {
            "operation" => "create",
            "topic_id" => topic.id.to_s,
            "raw" => "Anonymous reply",
            "author_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess).and not_change { topic.posts.count }
    end

    it "defaults to creating a post" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic

      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "raw" => "Default create reply",
            "author_username" => admin.username,
          },
          item: item,
        )
      end.to change { topic.posts.count }.by(1)

      expect(topic.posts.order(:id).last.raw).to eq("Default create reply")
    end

    it "falls back to the system user when no author is configured" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic

      execute_node(
        configuration: {
          "operation" => "create",
          "topic_id" => topic.id.to_s,
          "raw" => "Created by workflows",
        },
        item: item,
      )

      expect(topic.posts.order(:id).last.user_id).to eq(Discourse.system_user.id)
    end

    it "creates a reply to a specific post number" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic

      execute_node(
        configuration: {
          "operation" => "create",
          "topic_id" => topic.id.to_s,
          "raw" => "Threaded reply",
          "reply_to_post_number" => first_post.post_number.to_s,
        },
        item: item,
      )

      expect(topic.posts.order(:id).last.reply_to_post_number).to eq(first_post.post_number)
    end

    it "creates a whisper when configured" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "create",
              "topic_id" => topic.id.to_s,
              "raw" => "Workflow whisper",
              "whisper" => true,
              "author_username" => admin.username,
            },
            item: item,
          )
      end.to change { topic.posts.count }.by(1)

      reply = topic.posts.order(:id).last
      expect(reply.post_type).to eq(Post.types[:whisper])
      expect(result["post"]).to include(
        "id" => reply.id,
        "post_type" => Post.types[:whisper],
        "raw" => "Workflow whisper",
      )
    end

    it "raises when the create author cannot whisper" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic

      expect do
        execute_node(
          configuration: {
            "operation" => "create",
            "topic_id" => topic.id.to_s,
            "raw" => "Unauthorized whisper",
            "whisper" => true,
            "author_username" => user.username,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess).and not_change { topic.posts.count }
    end

    it "raises when the create author cannot be found" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)

      expect do
        execute_node(
          configuration: {
            "operation" => "create",
            "topic_id" => first_post.topic_id.to_s,
            "raw" => "Workflow reply",
            "author_username" => "nonexistent_user",
          },
          item: item,
        )
      end.to raise_error(DiscourseWorkflows::NodeError, "User 'nonexistent_user' not found")
    end

    it "raises when the create author cannot see the topic" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_topic = create_post(user: admin, category: private_category).topic

      expect do
        execute_node(
          configuration: {
            "operation" => "create",
            "topic_id" => hidden_topic.id.to_s,
            "raw" => "Workflow reply",
            "author_username" => user.username,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess).and not_change { hidden_topic.posts.count }
    end

    it "raises when creating in a closed or archived topic" do
      first_post = Fabricate(:post, user: user, raw: "First post", post_number: 1)
      topic = first_post.topic
      topic.update!(closed: true)

      expect do
        execute_node(
          configuration: {
            "operation" => "create",
            "topic_id" => topic.id.to_s,
            "raw" => "Workflow reply",
          },
          item: item,
        )
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        /Cannot create a post in a closed or archived topic/,
      )
    end

    it "edits a post for the configured editor" do
      post = Fabricate(:post, user: user, raw: "Original post", post_number: 1)
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "edit",
              "post_id" => post.id.to_s,
              "raw" => "Edited by workflow",
              "editor_username" => admin.username,
            },
            item: item,
          )
      end.not_to change { Post.count }

      post.reload
      expect(post.raw).to eq("Edited by workflow")
      expect(result["post"]).to include(
        "id" => post.id,
        "topic_id" => post.topic_id,
        "username" => user.username,
        "raw" => "Edited by workflow",
        "cooked" => post.cooked,
      )
    end

    it "raises when the editor cannot edit the post" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_post = create_post(user: admin, category: private_category)

      expect do
        execute_node(
          configuration: {
            "operation" => "edit",
            "post_id" => hidden_post.id.to_s,
            "raw" => "Hidden edit",
            "editor_username" => user.username,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(hidden_post.reload.raw).not_to eq("Hidden edit")
    end

    it "gets a visible post with selected body fields" do
      post = Fabricate(:post, user: user, raw: "Visible post body", post_number: 1)

      result =
        execute_node(
          configuration: {
            "operation" => "get",
            "post_id" => post.id.to_s,
            "include_raw" => true,
            "include_cooked" => false,
          },
          item: item,
        )

      expect(result["post"]).to include(
        "id" => post.id,
        "topic_id" => post.topic_id,
        "post_url" => post.url,
        "username" => user.username,
        "raw" => "Visible post body",
      )
      expect(result["post"]).not_to have_key("cooked")
    end

    it "raises when the actor cannot see the post" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_post = create_post(user: admin, category: private_category)

      expect do
        execute_node(
          configuration: {
            "operation" => "get",
            "post_id" => hidden_post.id.to_s,
            "actor_username" => other_user.username,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "raises when the anonymous actor cannot see the post" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_post = create_post(user: admin, category: private_category)

      expect do
        execute_node(
          configuration: {
            "operation" => "get",
            "post_id" => hidden_post.id.to_s,
            "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
          },
          item: item,
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "lists posts matching UI filter fields" do
      topic_1 =
        Fabricate(:topic, category: category, tags: [tag], user: user, title: "First report topic")
      matching_post =
        Fabricate(:post, topic: topic_1, user: user, post_number: 1, raw: "alpha body")
      topic_2 =
        Fabricate(:topic, category: other_category, user: other_user, title: "Other ignored topic")
      Fabricate(:post, topic: topic_2, user: other_user, post_number: 1, raw: "beta body")

      result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "created_after" => "7 days ago",
            "categories" => category.slug,
            "tags" => [tag.name],
            "usernames" => user.username,
            "post_type" => "first",
            "order" => "latest",
            "limit" => "10",
          },
          item: item,
        ).first

      expect(result.map { |output_item| output_item.dig("json", "post", "id") }).to contain_exactly(
        matching_post.id,
      )
      expect(result.first.dig("json", "post")).to include(
        "category_name" => category.name,
        "tags" => [tag.name],
        "raw" => "alpha body",
      )
    end

    it "lists posts matching the query field" do
      topic = Fabricate(:topic, category: category, user: user, title: "Query field topic")
      matching_post = Fabricate(:post, topic: topic, user: user, post_number: 1, raw: "query body")
      ignored_topic =
        Fabricate(:topic, category: other_category, user: other_user, title: "Ignored query topic")
      Fabricate(:post, topic: ignored_topic, user: other_user, post_number: 1, raw: "ignored body")

      result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "query" => "category:#{category.slug} username:#{user.username}",
            "categories" => other_category.slug,
            "limit" => "10",
          },
          item: item,
        ).first

      expect(result.map { |output_item| output_item.dig("json", "post", "id") }).to contain_exactly(
        matching_post.id,
      )
    end

    it "lists posts matching the advanced filter" do
      matching_post = Fabricate(:post, user: user, raw: "advanced body")
      Fabricate(:post, user: other_user, raw: "ignored body")

      result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "advanced_filter" => "username:#{user.username}",
            "limit" => "10",
          },
          item: item,
        ).first

      expect(result.map { |output_item| output_item.dig("json", "post", "id") }).to contain_exactly(
        matching_post.id,
      )
    end

    it "lists regular posts by default and explicit action posts" do
      topic = Fabricate(:topic, category: category, user: user)
      regular_post = Fabricate(:post, topic: topic, user: user, post_number: 1, raw: "regular body")
      small_action_post =
        Fabricate(
          :post,
          topic: topic,
          user: admin,
          post_number: 2,
          post_type: Post.types[:small_action],
        )

      default_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "limit" => "10",
          },
          item: item,
        ).first
      all_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "post_type" => "all",
            "limit" => "10",
          },
          item: item,
        ).first
      small_action_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "post_type" => "small_action",
            "limit" => "10",
          },
          item: item,
        ).first

      expect(default_result.map { |output_item| output_item.dig("json", "post", "id") }).to include(
        regular_post.id,
      )
      expect(
        default_result.map { |output_item| output_item.dig("json", "post", "id") },
      ).not_to include(small_action_post.id)
      expect(all_result.map { |output_item| output_item.dig("json", "post", "id") }).to include(
        regular_post.id,
        small_action_post.id,
      )
      expect(
        small_action_result.map { |output_item| output_item.dig("json", "post", "id") },
      ).to contain_exactly(small_action_post.id)
    end

    it "respects actor permissions when listing posts" do
      restricted = Fabricate(:category, read_restricted: true)
      Fabricate(:category_group, category: restricted, group: Group[:staff], permission_type: 0)
      restricted_topic = Fabricate(:topic, category: restricted)
      restricted_post = Fabricate(:post, topic: restricted_topic, post_number: 1)

      system_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "categories" => restricted.slug,
          },
          item: item,
        ).first
      user_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "categories" => restricted.slug,
            "actor_username" => other_user.username,
          },
          item: item,
        ).first

      expect(
        system_result.map { |output_item| output_item.dig("json", "post", "id") },
      ).to contain_exactly(restricted_post.id)
      expect(user_result).to eq([])
    end

    it "enforces the result count cap" do
      3.times { |index| Fabricate(:post, raw: "post #{index}", post_number: index + 1) }

      limited_result =
        execute_node_output(
          configuration: {
            "operation" => "list",
            "limit" => "2",
          },
          item: item,
        ).first

      expect(limited_result.length).to eq(2)
    end

    it "raises for invalid advanced filters" do
      expect do
        execute_node(
          configuration: {
            "operation" => "list",
            "advanced_filter" => "invalidfilter",
          },
          item: item,
        )
      end.to raise_error(DiscourseWorkflows::NodeError, /Invalid post filter fragment/)
    end
  end
end
