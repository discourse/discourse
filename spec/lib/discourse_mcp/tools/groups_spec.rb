# frozen_string_literal: true

describe DiscourseMcp::Tools::CreateGroup do
  describe "level constants" do
    it "matches the group levels the models define" do
      expect(described_class::VISIBILITY_LEVELS).to eq(Group.visibility_levels.values.uniq.sort)
      expect(described_class::ALIAS_LEVELS).to eq(Group::ALIAS_LEVELS.values.uniq.sort)
      expect(described_class::NOTIFICATION_LEVELS).to eq(
        GroupUser.notification_levels.values.uniq.sort,
      )
    end
  end
end
