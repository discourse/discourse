# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserSearch::V1 do
  describe "#valid?" do
    it "returns true when the query is present" do
      trigger = described_class.new("workflow query")

      expect(trigger).to be_valid
    end

    it "returns false when the query is blank" do
      trigger = described_class.new("")

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the query", :aggregate_failures do
      trigger = described_class.new("workflow query")
      output = trigger.output

      expect(output).to eq(query: "workflow query", actor: nil)
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns the searching user as actor", :aggregate_failures do
      user = Fabricate(:user)
      output = described_class.new("workflow query", acting_user: user).output

      expect(output[:actor]).to include(id: user.id, username: user.username)
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from the event Search fires" do
      user = Fabricate(:user)
      event =
        DiscourseEvent.track(:user_search) do
          Search.new("workflow query", search_type: :header, guardian: user.guardian).execute
        end

      expect(described_class.new(*event[:params]).output[:actor]).to include(id: user.id)
    end
  end
end
