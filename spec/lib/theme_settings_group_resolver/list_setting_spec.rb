# frozen_string_literal: true

RSpec.describe ThemeSettingsGroupResolver::ListSetting do
  fab!(:user)
  fab!(:group)
  fab!(:other_group, :group)

  before { group.add(user) }

  describe ".applies?" do
    it "applies only to opted-in list settings" do
      expect(described_class.applies?(type: "list", resolve_group_membership: true)).to eq(true)
      expect(described_class.applies?(type: "list", resolve_group_membership: false)).to eq(false)
      expect(described_class.applies?(type: "objects", resolve_group_membership: true)).to eq(false)
    end
  end

  describe "#resolve!" do
    it "replaces the group list with a user_in boolean" do
      settings = { allowed_groups: "#{group.id}|#{other_group.id}" }

      described_class.new(
        setting_name: :allowed_groups,
        setting_info: {
        },
        guardian: user.guardian,
      ).resolve!(settings)

      expect(settings).to eq(user_in_allowed_groups: true)
    end

    it "returns false for empty group lists and anonymous users" do
      settings = { allowed_groups: "" }

      described_class.new(
        setting_name: :allowed_groups,
        setting_info: {
        },
        guardian: Guardian.new,
      ).resolve!(settings)

      expect(settings).to eq(user_in_allowed_groups: false)
    end
  end
end
