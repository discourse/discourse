# frozen_string_literal: true

RSpec.describe ThemeSettingsTagResolver do
  fab!(:tag) { Fabricate(:tag, name: "support") }
  fab!(:other_tag) { Fabricate(:tag, name: "feature") }

  let(:guardian) { Guardian.new }
  let(:schema) do
    {
      properties: {
        tags: {
          type: "tags",
        },
        children: {
          type: "objects",
          schema: {
            properties: {
              selected_tags: {
                type: "tags",
              },
            },
          },
        },
      },
    }
  end
  let(:settings) do
    {
      :styles => [{ "tags" => [tag.name], "children" => [{ selected_tags: [other_tag.name] }] }],
      "theme_setting_type_info" => {
        styles: {
          type: "objects",
          schema:,
        },
      },
    }
  end

  it "automatically adds source-name object arrays in one query across themes without mutating settings" do
    settings[:styles].first["tags"] << tag.name
    original = settings.deep_dup
    second = settings.deep_dup
    second[:styles] = [{ "tags" => [other_tag.name, tag.name.upcase, tag.name] }]
    result = nil
    queries =
      track_sql_queries do
        result =
          described_class.resolve(settings_by_theme: { 1 => settings, 2 => second }, guardian:)
      end

    first = result.dig(1, :styles, 0)
    expect(first.fetch("tags")).to eq([tag.name, tag.name])
    expect(first.fetch("tag_objects")).to eq(
      [{ "id" => tag.id, "name" => tag.name }, { "id" => tag.id, "name" => tag.name }],
    )
    expect(first.fetch("tag_objects").map { |object| object.fetch("name") }).to eq(
      first.fetch("tags"),
    )
    expect(first.fetch("children").first.fetch("tag_objects")).to eq(
      [{ "id" => other_tag.id, "name" => other_tag.name }],
    )
    expect(result.dig(2, :styles, 0, "tag_objects")).to eq(
      [
        { "id" => other_tag.id, "name" => other_tag.name },
        { "id" => tag.id, "name" => tag.name.upcase },
        { "id" => tag.id, "name" => tag.name },
      ],
    )
    expect(queries.count { |sql| sql.match?(/SELECT .*FROM "tags"/m) }).to eq(1)
    expect(settings).to eq(original)
  end

  it "treats numeric strings as names, ignores unresolved integers and replaces submitted metadata" do
    numeric_tag = Fabricate(:tag, name: tag.id.to_s)
    settings[:styles] = [
      { tags: [numeric_tag.name, tag.id, "missing"], tag_objects: [{ "id" => tag.id }] },
    ]
    object =
      described_class.resolve(settings_by_theme: { 1 => settings }, guardian:).dig(1, :styles, 0)

    expect(object.fetch("tag_objects")).to eq(
      [{ "id" => numeric_tag.id, "name" => numeric_tag.name }],
    )
    expect(object).not_to have_key(:tag_objects)
  end

  it "does not query for empty selections but includes empty companion arrays" do
    settings[:styles] = [{ "tags" => [] }, {}]
    result = nil
    queries =
      track_sql_queries do
        result = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)
      end

    expect(result.dig(1, :styles)).to eq(
      [{ "tags" => [], "tag_objects" => [] }, { "tag_objects" => [] }],
    )
    expect(queries).to be_empty
  end

  it "preserves declared author tag_objects fields and legacy tag lists without querying" do
    schema[:properties].delete(:children)
    schema[:properties]["tag_objects"] = { type: "string" }
    settings[:styles] = [{ "tags" => [tag.name], "tag_objects" => "author data" }]
    settings[:legacy_tags] = tag.name
    settings["theme_setting_type_info"][:legacy_tags] = { type: "list", list_type: "tag" }
    result = nil
    queries =
      track_sql_queries do
        result = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)
      end

    expect(result).to eq(1 => settings)
    expect(queries).to be_empty
  end

  it "still resolves nested objects when the parent declares its own companion field" do
    schema[:properties][:tag_objects] = { type: "string" }
    settings[:styles].first["tag_objects"] = "author data"
    result = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)

    expect(result.dig(1, :styles, 0, "tag_objects")).to eq("author data")
    expect(result.dig(1, :styles, 0, "children", 0, "tag_objects")).to eq(
      [{ "id" => other_tag.id, "name" => other_tag.name }],
    )
  end

  it "does not touch unrelated object values or query tags for schemas without tag properties" do
    schema[:properties] = { title: { type: "string" } }
    settings[:styles] = [nil]
    result = nil
    queries =
      track_sql_queries do
        result = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)
      end

    expect(result).to eq(1 => settings)
    expect(queries).to be_empty
  end

  it "combines all direct tag selections while ignoring unrelated values" do
    schema[:properties][:additional_tags] = { type: "tags" }
    schema[:properties][:title] = { type: "string" }
    settings[:styles] = [{ tags: [tag.name], additional_tags: [other_tag.name], title: "ignored" }]
    result = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)

    expect(result.dig(1, :styles, 0, "tag_objects")).to eq(
      [{ "id" => tag.id, "name" => tag.name }, { "id" => other_tag.id, "name" => other_tag.name }],
    )
  end

  it "does not retain stale objects after renames, deletion or name reuse" do
    old_name = tag.name
    input = settings.deep_dup
    tag.update!(name: "renamed")
    expect(
      described_class.resolve(settings_by_theme: { 1 => input }, guardian:).dig(
        1,
        :styles,
        0,
        "tag_objects",
      ),
    ).to eq([])
    tag.destroy!
    replacement = Fabricate(:tag, name: old_name)
    result = described_class.resolve(settings_by_theme: { 1 => input }, guardian:)

    expect(result.dig(1, :styles, 0, "tag_objects")).to eq(
      [{ "id" => replacement.id, "name" => replacement.name }],
    )
  end

  it "filters by visitor visibility without sharing resolved objects across visitors" do
    group = Fabricate(:group)
    Fabricate(:tag_group, tags: [tag], permissions: { group.name => 1 })
    user = Fabricate(:user)
    group.add(user)
    anonymous = described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)
    expect(anonymous.dig(1, :styles, 0, "tag_objects")).to eq([])
    member = described_class.resolve(settings_by_theme: { 1 => settings }, guardian: user.guardian)
    expect(member.dig(1, :styles, 0, "tag_objects")).to eq([{ "id" => tag.id, "name" => tag.name }])
    expect(described_class.resolve(settings_by_theme: { 1 => settings }, guardian:)).to eq(
      anonymous,
    )
  end
end
