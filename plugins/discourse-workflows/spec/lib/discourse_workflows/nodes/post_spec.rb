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

    it "uses a hard-coded memory cap" do
      stub_const(described_class, :DEFAULT_MEMORY_CAP_MB, 1) do
        large_post =
          Fabricate(
            :post,
            raw: "x" * (1.megabyte + 1000),
            cooked: "<p>large</p>",
            post_number: 1,
            skip_validation: true,
          )
        messages = nil

        memory_result =
          execute_node_output(
            configuration: {
              "operation" => "list",
              "query" => "topic:#{large_post.topic_id}",
              "memory_cap_mb" => "50",
              "include_raw" => true,
            },
            item: item,
          ) { |exec_ctx| messages = exec_ctx.log.entries.map { |entry| entry["message"] } }.first

        expect(memory_result).to eq([])
        expect(messages).to include(a_string_matching(/Post list truncated/))
      end
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
