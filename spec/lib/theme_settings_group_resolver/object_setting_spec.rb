# frozen_string_literal: true

RSpec.describe ThemeSettingsGroupResolver::ObjectSetting do
  fab!(:user)
  fab!(:group)
  fab!(:other_group, :group)

  before { group.add(user) }

  describe ".applies?" do
    it "applies only to object settings" do
      expect(described_class.applies?(type: "objects")).to eq(true)
      expect(described_class.applies?(type: "list")).to eq(false)
    end
  end

  describe "#resolve!" do
    it "replaces opted-in group properties with user_in booleans" do
      settings = {
        menu_sections: [
          {
            "name" => "member section",
            "groups" => [group.id],
            "visible_groups" => [other_group.id],
          },
          {
            "name" => "other section",
            "groups" => [other_group.id],
            "visible_groups" => [group.id],
          },
        ],
      }

      resolve!(settings, schema: section_schema)

      expect(settings[:menu_sections]).to eq(
        [
          {
            "name" => "member section",
            "user_in_groups" => true,
            "visible_groups" => [other_group.id],
          },
          { "name" => "other section", "user_in_groups" => false, "visible_groups" => [group.id] },
        ],
      )
    end

    it "resolves nested object group properties" do
      settings = {
        menu_sections: [
          {
            "name" => "section",
            "links" => [
              { "name" => "member link", "groups" => [group.id] },
              { "name" => "other link", "groups" => [other_group.id] },
            ],
          },
        ],
      }

      resolve!(settings, schema: nested_groups_schema)

      expect(settings[:menu_sections]).to eq(
        [
          {
            "name" => "section",
            "links" => [
              { "name" => "member link", "user_in_groups" => true },
              { "name" => "other link", "user_in_groups" => false },
            ],
          },
        ],
      )
    end

    it "does not mutate the original object value" do
      original_objects = [{ "name" => "section", "groups" => [group.id] }]
      settings = { menu_sections: original_objects }

      resolve!(settings, schema: section_schema)

      expect(original_objects).to eq([{ "name" => "section", "groups" => [group.id] }])
      expect(settings[:menu_sections]).not_to equal(original_objects)
    end

    it "preserves symbol keys when resolving symbol-keyed objects" do
      settings = { menu_sections: [{ name: "section", groups: [group.id] }] }

      resolve!(settings, schema: section_schema)

      expect(settings[:menu_sections]).to eq([{ name: "section", user_in_groups: true }])
    end

    it "leaves settings unchanged when no group properties opt in" do
      original_objects = [{ "name" => "section", "groups" => [group.id] }]
      settings = { menu_sections: original_objects }
      schema = { name: "section", properties: { groups: { type: "groups" } } }

      resolve!(settings, schema:)

      expect(settings[:menu_sections]).to equal(original_objects)
    end

    it "handles anonymous users, auto-groups, empty arrays, and multiple groups" do
      settings = {
        menu_sections: [
          { "name" => "logged in", "groups" => [Group::AUTO_GROUPS[:logged_in_users]] },
          { "name" => "anonymous", "groups" => [Group::AUTO_GROUPS[:anonymous_users]] },
          { "name" => "empty", "groups" => [] },
          { "name" => "multiple", "groups" => [group.id, other_group.id] },
        ],
      }

      resolve!(settings, schema: section_schema, guardian: Guardian.new)

      expect(settings[:menu_sections].pluck("user_in_groups")).to eq([false, true, false, false])
    end
  end

  def resolve!(settings, schema:, guardian: user.guardian)
    described_class.new(
      setting_name: :menu_sections,
      setting_info: {
        schema:,
      },
      guardian:,
    ).resolve!(settings)
  end

  def section_schema
    {
      name: "section",
      properties: {
        groups: {
          type: "groups",
          resolve_group_membership: true,
        },
        visible_groups: {
          type: "groups",
        },
        links: {
          type: "objects",
          schema: {
            name: "link",
            properties: {
              groups: {
                type: "groups",
                resolve_group_membership: true,
              },
            },
          },
        },
      },
    }
  end

  def nested_groups_schema
    {
      name: "section",
      properties: {
        links: {
          type: "objects",
          schema: {
            name: "link",
            properties: {
              groups: {
                type: "groups",
                resolve_group_membership: true,
              },
            },
          },
        },
      },
    }
  end
end
