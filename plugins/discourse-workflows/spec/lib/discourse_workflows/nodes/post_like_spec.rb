# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLike::V1 do
  fab!(:post)
  fab!(:actor, :user)

  describe "#execute" do
    let(:configuration) do
      { "operation" => operation, "post_id" => post.id.to_s, "actor_username" => actor.username }
    end

    context "with like operation" do
      let(:operation) { "like" }

      it "likes the post as the actor" do
        result = execute_node(configuration:)

        expect(result).to eq("post_id" => post.id, "username" => actor.username, "changed" => true)
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
