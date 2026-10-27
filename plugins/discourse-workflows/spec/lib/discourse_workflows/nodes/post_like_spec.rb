# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLike::V1 do
  fab!(:post)
  fab!(:actor, :user)

  describe ".deprecation" do
    it "is replaced by Like post and Unlike post at both versions", :aggregate_failures do
      [described_class, DiscourseWorkflows::Nodes::PostLike::V2].each do |node_class|
        expect(node_class.deprecation).to include(
          replaced_by: %w[action:like_post action:unlike_post],
        )
        expect(node_class.deprecation).not_to have_key(:superseded_by)
        expect(node_class).not_to be_palette_visible
      end
    end
  end

  describe ".upgrade" do
    let(:shared) { { "post_id" => "={{ $json.post.id }}", "actor_username" => "system" } }
    let(:notes) do
      %w[
        discourse_workflows.node_upgrades.post_like_output
        discourse_workflows.node_upgrades.post_like_username
      ]
    end

    it "moves liking to Like post, dropping the operation" do
      expect(described_class.upgrade(shared.merge("operation" => "like", "extra" => "x"))).to eq(
        type: "action:like_post",
        parameters: shared,
        notes:,
      )
    end

    it "treats a node without an operation as liking" do
      expect(described_class.upgrade(shared)).to include(type: "action:like_post")
    end

    it "moves unliking to Unlike post" do
      expect(described_class.upgrade(shared.merge("operation" => "unlike"))).to eq(
        type: "action:unlike_post",
        parameters: shared,
        notes:,
      )
    end

    it "leaves a node whose operation is an expression or unknown to be replaced by hand" do
      expect(
        described_class.upgrade(shared.merge("operation" => "={{ $json.operation }}")),
      ).to be_nil
      expect(described_class.upgrade(shared.merge("operation" => "toggle"))).to be_nil
    end

    it "upgrades a saved unlike node to Unlike post 1.0, keeping its name, with both notes" do
      node = {
        "id" => "node-1",
        "type" => "action:post_like",
        "typeVersion" => "1.0",
        "name" => "Like post",
        "parameters" => shared.merge("operation" => "unlike"),
      }

      result = DiscourseWorkflows::NodeUpgrader.call([node])

      expect(result.nodes.sole).to include(
        "id" => "node-1",
        "name" => "Like post",
        "type" => "action:unlike_post",
        "typeVersion" => "1.0",
        "parameters" => shared,
      )
      expect(result.upgrades.sole.notes).to eq(notes.map { |key| I18n.t(key) })
    end
  end

  describe "#execute" do
    let(:configuration) do
      { "operation" => operation, "post_id" => post.id.to_s, "actor_username" => actor.username }
    end

    context "with like operation" do
      let(:operation) { "like" }

      it "likes the post as the actor" do
        result = execute_node(configuration:)

        expect(result).to include(
          "post_id" => post.id,
          "username" => actor.username,
          "changed" => true,
          "actor" => include("username" => actor.username),
        )
        expect(result).to match_node_output_schema(described_class)
        expect(post.reload.like_count).to eq(1)
      end

      it "leaves an existing like untouched" do
        PostActionCreator.like(actor, post)

        expect(execute_node(configuration:)).to include("changed" => false)
        expect(post.reload.like_count).to eq(1)
      end

      it "fails when the actor cannot like the post" do
        configuration["actor_username"] = post.user.username

        expect { execute_node(configuration:) }.to raise_error(DiscourseWorkflows::NodeError)
      end
    end

    context "with unlike operation" do
      let(:operation) { "unlike" }

      it "removes the actor's like" do
        PostActionCreator.like(actor, post)

        expect(execute_node(configuration:)).to include("changed" => true)
        expect(post.reload.like_count).to eq(0)
      end

      it "does nothing when the actor has not liked the post" do
        expect(execute_node(configuration:)).to include("changed" => false)
      end
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostLike::V2 do
  fab!(:post)
  fab!(:actor, :user)

  describe ".upgrade" do
    let(:shared) { { "post_id" => "={{ $json.post.id }}", "actor_username" => "system" } }
    let(:notes) { ["discourse_workflows.node_upgrades.post_like_output"] }

    it "routes each operation to its node, with the post_id note only" do
      expect(described_class.upgrade(shared.merge("operation" => "like"))).to eq(
        type: "action:like_post",
        parameters: shared,
        notes:,
      )
      expect(described_class.upgrade(shared.merge("operation" => "unlike"))).to eq(
        type: "action:unlike_post",
        parameters: shared,
        notes:,
      )
      expect(
        described_class.upgrade(shared.merge("operation" => "={{ $json.operation }}")),
      ).to be_nil
    end

    it "upgrades a saved node to Like post 1.0" do
      node = {
        "id" => "node-1",
        "type" => "action:post_like",
        "typeVersion" => "2.0",
        "name" => "Like it",
        "parameters" => shared.merge("operation" => "like"),
      }

      result = DiscourseWorkflows::NodeUpgrader.call([node])

      expect(result.nodes.sole).to include(
        "id" => "node-1",
        "name" => "Like it",
        "type" => "action:like_post",
        "typeVersion" => "1.0",
        "parameters" => shared,
      )
      expect(result.upgrades.sole.notes).to eq(notes.map { |key| I18n.t(key) })
    end
  end

  it "returns the liker as actor", :aggregate_failures do
    result =
      execute_node(
        configuration: {
          "operation" => "like",
          "post_id" => post.id.to_s,
          "actor_username" => actor.username,
        },
      )

    expect(result).to include("post_id" => post.id, "changed" => true)
    expect(result["actor"]).to include("id" => actor.id, "username" => actor.username)
    expect(result).not_to have_key("username")
    expect(result).to match_node_output_schema(described_class)
  end
end
