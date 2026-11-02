# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostEdited::V2 do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:editor, :admin)
  fab!(:first_post) { create_post(user: user, raw: "First post") }

  describe "#output" do
    it "exposes the editor as actor", :aggregate_failures do
      events =
        DiscourseEvent.track_events(:post_edited) do
          first_post.revise(editor, raw: "Edited by another user")
        end

      output = described_class.new(*events.sole[:params]).output

      expect(output[:user]).to include(id: user.id)
      expect(output[:actor]).to include(id: editor.id, username: editor.username)
      expect(output).not_to have_key(:editor)
      expect(output).to match_node_output_schema(described_class)
    end

    it "has a null actor when the editor is unknown" do
      output = described_class.new(first_post).output

      expect(output).to include(actor: nil)
      expect(output).to match_node_output_schema(described_class)
    end
  end
end
