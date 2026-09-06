# frozen_string_literal: true

RSpec.describe ThemeSettingsGroupResolver do
  fab!(:user)
  fab!(:group)

  before { group.add(user) }

  describe ".resolve" do
    it "resolves list and object group memberships from type metadata" do
      settings = {
        allowed_groups: group.id.to_s,
        menu_sections: [{ "name" => "section", "groups" => [group.id] }],
        title: "Welcome",
      }
      type_info = {
        allowed_groups: {
          type: "list",
          resolve_group_membership: true,
        },
        menu_sections: {
          type: "objects",
          schema: {
            name: "section",
            properties: {
              groups: {
                type: "groups",
                resolve_group_membership: true,
              },
            },
          },
        },
        title: {
          type: "string",
        },
      }

      expect(
        described_class.resolve(settings_hash: settings, type_info:, guardian: user.guardian),
      ).to eq(
        {
          user_in_allowed_groups: true,
          menu_sections: [{ "name" => "section", "user_in_groups" => true }],
          title: "Welcome",
        },
      )
    end
  end
end
