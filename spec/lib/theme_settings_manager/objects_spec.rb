# frozen_string_literal: true

RSpec.describe ThemeSettingsManager::Objects do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root.join("spec/fixtures/theme_settings/objects_settings.yaml")}")
    field = theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  it "can store a list of objects" do
    new_value = [
      {
        "name" => "section 3",
        "links" => [
          { "name" => "section 3 link 1", "url" => "https://section3link1.com" },
          { "name" => "section 3 link 2" },
        ],
      },
      {
        "name" => "section 4",
        "links" => [{ "name" => "section 4 link 1", "url" => "https://section4link1.com" }],
      },
    ]

    theme_setting[:objects_setting].value = new_value

    expect(theme.reload.settings[:objects_setting].value).to eq(new_value)
  end

  it "rejects invalid root and nested object shapes before saving" do
    setting = theme_setting[:objects_setting]
    previous_value = setting.value
    [
      true,
      1,
      "{}",
      "[1]",
      [{ "name" => "Section", "links" => [1] }],
      [{ "links" => {} }],
    ].each do |value|
      expect { setting.value = value }.to raise_error(Discourse::InvalidParameters)
      expect(theme.reload.settings[:objects_setting].value).to eq(previous_value)
    end
  end

  it "removes disallowed group ids before saving groups properties" do
    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      objects_setting:
        type: objects
        default: []
        schema:
          name: section
          properties:
            group_ids:
              type: groups
              disallowed_groups: "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:admins]}"
            links:
              type: objects
              schema:
                name: link
                properties:
                  group_ids:
                    type: groups
                    disallowed_groups: "#{Group::AUTO_GROUPS[:trust_level_0]}"
    YAML
    theme.save!

    theme.settings[:objects_setting].value = [
      {
        "group_ids" => [
          Group::AUTO_GROUPS[:everyone],
          Group::AUTO_GROUPS[:admins],
          Group::AUTO_GROUPS[:staff],
        ],
        "links" => [
          {
            "group_ids" => [Group::AUTO_GROUPS[:trust_level_0], Group::AUTO_GROUPS[:trust_level_1]],
          },
        ],
      },
    ]

    expect(theme.reload.settings[:objects_setting].value).to eq(
      [
        {
          "group_ids" => [Group::AUTO_GROUPS[:staff]],
          "links" => [{ "group_ids" => [Group::AUTO_GROUPS[:trust_level_1]] }],
        },
      ],
    )
  end

  it "raises the right error when there are objects which are not valid" do
    new_value = [
      { "name" => "section 3", "links" => [{ "url" => "https://some.url.no.name" }] },
      {
        "links" => [
          {
            "name" => "some name that exceeds the max length of 20 characters",
            "url" => "https://some.url",
          },
        ],
      },
    ]

    expect { theme_setting[:objects_setting].value = new_value }.to raise_error(
      Discourse::InvalidParameters,
      "The property at JSON Pointer '/0/links/0/name' must be present. The property at JSON Pointer '/1/name' must be present. The property at JSON Pointer '/1/links/0/name' must be at most 20 characters long.",
    )
  end

  describe "tag properties" do
    fab!(:tag) { Fabricate(:tag, name: "cat") }
    fab!(:other_tag) { Fabricate(:tag, name: "dog") }

    before do
      theme.set_field(target: :settings, name: :yaml, value: <<~YAML)
        tag_styles:
          type: objects
          default: []
          schema:
            name: tag style
            properties:
              tags:
                type: tags
              position:
                type: integer
              children:
                type: objects
                schema:
                  name: child
                  properties:
                    tags:
                      type: tags
      YAML
      theme.save!
    end

    it "stores mixed IDs and source names as names in root and nested properties without mutating input" do
      numeric_name_tag = Fabricate(:tag, name: tag.id.to_s)
      objects = [
        {
          tags: [tag.id, numeric_name_tag.name, tag.name],
          position: other_tag.id,
          children: [{ "tags" => [other_tag.name, other_tag.id] }],
        },
      ]
      original_objects = objects.deep_dup

      theme.update_setting(:tag_styles, objects)

      expected = [
        {
          "tags" => [tag.name, numeric_name_tag.name, tag.name],
          "position" => other_tag.id,
          "children" => [{ "tags" => [other_tag.name, other_tag.name] }],
        },
      ]
      expect(theme.reload.theme_settings.find_by!(name: "tag_styles").json_value).to eq(expected)
      expect(theme.settings[:tag_styles].value).to eq(expected)
      expect(objects).to eq(original_objects)
    end

    it "rejects invalid tag values without changing the saved selection" do
      theme.update_setting(:tag_styles, [{ tags: [tag.name] }])
      setting = theme.reload.settings[:tag_styles]

      [
        [99_999_999],
        [10**100],
        [0],
        [-1],
        [tag.id.to_f],
        [true],
        [nil],
        [{ id: tag.id }],
        [[tag.id]],
        tag.id,
      ].each do |tags|
        expect { setting.value = [{ tags: }] }.to raise_error(Discourse::InvalidParameters)
        expect(theme.reload.settings[:tag_styles].value).to eq([{ "tags" => [tag.name] }])
      end
    end

    it "batches tag lookups across objects and nested properties" do
      objects = Array.new(5) { { tags: [tag.id], children: [{ tags: [other_tag.id] }] } }
      setting = theme.settings[:tag_styles]

      queries = track_sql_queries { setting.value = objects }

      expect(queries.grep(/FROM "tags"/).size).to eq(2)
    end

    it "does not add an ID lookup for source-name-only submissions" do
      setting = theme.settings[:tag_styles]
      objects = [{ tags: [tag.name] }]

      queries = track_sql_queries { setting.value = objects }

      expect(queries.grep(/FROM "tags"/).size).to eq(1)
    end
  end

  describe "generated tag objects" do
    fab!(:tag)

    before do
      theme.set_field(target: :settings, name: :yaml, value: <<~YAML)
        styles:
          type: objects
          default:
            - tags: []
              tag_objects: { stale: { id: 999 } }
          schema:
            properties:
              tags:
                type: tags
              children:
                type: objects
                schema:
                  properties:
                    tags:
                      type: tags
              author_data:
                type: objects
                schema:
                  properties:
                    tags:
                      type: tags
                    tag_objects:
                      type: string
      YAML
      theme.save!
    end

    it "does not expose generated objects in defaults or persist them from submitted payloads" do
      setting = theme.settings[:styles]
      expect(setting.default).to eq([{ "tags" => [] }])
      input = [
        {
          tags: [tag.id],
          tag_objects: {
            tag.name => {
              id: tag.id,
              name: "forged",
            },
          },
          children: [{ tags: [], tag_objects: { "unselected" => { id: tag.id } } }],
          author_data: [{ tags: [], tag_objects: "author value" }],
        },
      ]
      original = input.deep_dup
      setting.value = input
      expected = [
        {
          "tags" => [tag.name],
          "children" => [{ "tags" => [] }],
          "author_data" => [{ "tags" => [], "tag_objects" => "author value" }],
        },
      ]

      expect(theme.theme_settings.find_by!(name: "styles").json_value).to eq(expected)
      expect(theme.reload.settings[:styles].value).to eq(expected)
      expect(input).to eq(original)
    end
  end

  describe "#categories" do
    fab!(:category_1, :category)
    fab!(:category_2, :category)
    fab!(:category_3) { Fabricate(:private_category, group: Fabricate(:group)) }
    fab!(:admin)

    it "returns an empty array when there are no properties of `categories` type" do
      expect(theme_setting[:objects_setting].categories(Guardian.new)).to eq([])
    end

    it "returns the categories record for all the properties of `categories` type in a flat array" do
      new_value = [
        {
          "category_ids" => [category_1.id, category_2.id],
          "child_categories" => [{ "category_ids" => [category_3.id] }],
        },
      ]

      theme_setting[:objects_with_categories].value = new_value

      expect(theme.reload.settings[:objects_with_categories].value).to eq(new_value)

      expect(theme.settings[:objects_with_categories].categories(Guardian.new)).to contain_exactly(
        category_1,
        category_2,
      )

      expect(
        theme.settings[:objects_with_categories].categories(Guardian.new(admin)),
      ).to contain_exactly(category_1, category_2, category_3)
    end
  end
end
