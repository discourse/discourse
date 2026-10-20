# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostReaction::V1 do
  fab!(:post)
  fab!(:actor, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|hugs"
  end

  describe "#execute" do
    let(:configuration) do
      {
        "operation" => operation,
        "post_id" => post.id.to_s,
        "reaction" => ":laughing:",
        "if_exists" => if_exists,
        "actor_username" => actor.username,
      }
    end
    let(:if_exists) { "keep" }

    def react(reaction)
      DiscourseReactions::PostReaction::Toggle.call(
        params: {
          post_id: post.id,
          reaction:,
        },
        guardian: actor.guardian,
      )
    end

    def current_reaction
      DiscourseReactions::ReactionManager.reaction_value_for(user: actor, post:)
    end

    context "with add operation" do
      let(:operation) { "add" }

      it "reacts to the post as the actor" do
        result = execute_node(configuration:)

        expect(result).to eq(
          "post_id" => post.id,
          "username" => actor.username,
          "reaction" => "laughing",
          "previous_reaction" => nil,
          "changed" => true,
        )
        expect(result).to match_node_output_schema(described_class)
        expect(current_reaction).to eq("laughing")
      end

      it "keeps a different existing reaction by default" do
        react("hugs")

        expect(execute_node(configuration:)).to include(
          "reaction" => "hugs",
          "previous_reaction" => "hugs",
          "changed" => false,
        )
        expect(current_reaction).to eq("hugs")
      end

      context "when replacing existing reactions" do
        let(:if_exists) { "replace" }

        it "replaces a different existing reaction" do
          react("hugs")

          expect(execute_node(configuration:)).to include(
            "reaction" => "laughing",
            "previous_reaction" => "hugs",
            "changed" => true,
          )
          expect(current_reaction).to eq("laughing")
        end
      end

      it "fails when the reaction is not enabled" do
        configuration["reaction"] = "rocket"

        expect { execute_node(configuration:) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /#{I18n.t("discourse_reactions.errors.reaction_unavailable")}/,
        )
      end

      it "fails when the actor cannot react to the post" do
        post.topic.update!(archived: true)

        expect { execute_node(configuration:) }.to raise_error(DiscourseWorkflows::NodeError)
      end
    end

    context "with remove operation" do
      let(:operation) { "remove" }

      it "removes the actor's matching reaction" do
        react("laughing")

        expect(execute_node(configuration:)).to include(
          "reaction" => nil,
          "previous_reaction" => "laughing",
          "changed" => true,
        )
        expect(current_reaction).to be_nil
      end

      it "leaves a different reaction in place" do
        react("hugs")

        expect(execute_node(configuration:)).to include("reaction" => "hugs", "changed" => false)
        expect(current_reaction).to eq("hugs")
      end
    end
  end
end
