# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserCreated::V1 do
  fab!(:user)

  describe "#valid?" do
    it "returns true for a human user" do
      expect(described_class.new(user)).to be_valid
    end

    it "returns false when the user is missing" do
      expect(described_class.new(nil)).not_to be_valid
    end

    it "returns false for bot users" do
      expect(described_class.new(Discourse.system_user)).not_to be_valid
    end
  end

  describe "#user_id" do
    it "returns the created user ID" do
      expect(described_class.new(user).user_id).to eq(user.id)
    end
  end

  describe "#output" do
    it "returns the user payload", :aggregate_failures do
      output = described_class.new(user).output

      expect(output[:user]).to include(
        id: user.id,
        username: user.username,
        trust_level: user.trust_level,
        staged: false,
        created_at: user.created_at.iso8601,
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "flags staged users in the payload" do
      staged_user = Fabricate(:user, staged: true)

      expect(described_class.new(staged_user).output[:user]).to include(staged: true)
    end
  end

  describe "#matches?" do
    it "matches regular and staged users" do
      staged_user = Fabricate(:user, staged: true)

      expect(described_class.new(user).matches?(trigger_context({}))).to eq(true)
      expect(described_class.new(staged_user).matches?(trigger_context({}))).to eq(true)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
