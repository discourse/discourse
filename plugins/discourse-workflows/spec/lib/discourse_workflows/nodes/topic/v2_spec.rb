# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Topic::V2 do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[3]) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:, user: author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }

  it "creates a topic and returns the author as user", :aggregate_failures do
    result =
      execute_node(
        configuration: {
          "operation" => "create",
          "title" => "Workflow topic",
          "raw" => "First post body",
          "category_id" => category.id.to_s,
          "actor_username" => admin.username,
        },
      )

    created = Topic.last
    expect(result["user"]).to include("id" => admin.id, "trust_level" => admin.trust_level)
    expect(result["post"]).to include(
      "id" => created.first_post.id,
      "url" => created.first_post.full_url,
      "category_slug" => category.slug,
    )
    expect(result["post"]).not_to have_key("trust_level")
    expect(result).to match_node_output_schema(described_class)
  end

  it "gets a topic with its author as user", :aggregate_failures do
    result = execute_node(configuration: { "operation" => "get", "topic_id" => topic.id.to_s })

    expect(result["user"]).to include(
      "id" => author.id,
      "trust_level" => TrustLevel[3],
      "staff" => false,
    )
    expect(result.dig("post", "id")).to eq(first_post.id)
  end

  it "lists topics with tags and uploads in a constant number of queries", :aggregate_failures do
    SiteSetting.tagging_enabled = true
    tag = Fabricate(:tag)
    upload = Fabricate(:upload)
    topic.update!(tags: [tag])
    UploadReference.create!(target: first_post, upload:)
    config = { "operation" => "list", "query" => "category:#{category.slug}", "limit" => "10" }

    execute_node_output(configuration: config)
    initial = track_sql_queries { execute_node_output(configuration: config) }.size

    others =
      Array.new(2) do
        other = Fabricate(:topic, category:, user: Fabricate(:user), tags: [tag])
        post = Fabricate(:post, topic: other, user: other.user)
        UploadReference.create!(target: post, upload:)
        other
      end

    result = nil
    queries = track_sql_queries { result = execute_node_output(configuration: config).first }

    entries = result.map { |item| item["json"] }
    expect(entries.map { |entry| entry.dig("user", "id") }).to contain_exactly(
      author.id,
      *others.map(&:user_id),
    )
    expect(entries.map { |entry| entry.dig("post", "tags") }).to all(eq([tag.name]))
    expect(entries.map { |entry| entry.dig("post", "upload_ids") }).to all(eq([upload.id]))
    expect(entries).to all(match_node_output_schema(described_class, configuration: config))
    expect(queries.size).to eq(initial)
  end

  it "returns the author when setting custom fields", :aggregate_failures do
    config = {
      "operation" => "set_custom_fields",
      "topic_id" => topic.id.to_s,
      "custom_fields" => {
        "values" => [{ "key" => "foo", "value" => "bar" }],
      },
      "actor_username" => admin.username,
    }

    result = execute_node(configuration: config)

    expect(result["user"]).to include("id" => author.id)
    expect(result).to match_node_output_schema(described_class, configuration: config)
  end
end
