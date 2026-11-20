# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserFirstLoggedIn::V1 do
  fab!(:user)

  describe "#valid?" do
    it "accepts human users" do
      expect(described_class.new(user)).to be_valid
      expect(described_class.new(nil)).not_to be_valid
      expect(described_class.new(Discourse.system_user)).not_to be_valid
    end
  end
end
