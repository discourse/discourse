# frozen_string_literal: true

RSpec.describe TagGroupSerializer do
  it "doesn't translate automatic group names in permissions" do
    staff_group = Group.find(Group::AUTO_GROUPS[:staff])
    staff_group.update_columns(name: "custom")

    tag_group = Fabricate(:tag_group)
    tag_group.permissions = [
      [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
    ]
    tag_group.save!

    serialized = TagGroupSerializer.new(tag_group, root: false).as_json

    expect(serialized[:permissions].keys).to contain_exactly(Group::AUTO_GROUPS[:staff])
  end

  it "doesn't return tag synonyms" do
    tag = Fabricate(:tag)
    synonym = Fabricate(:tag, target_tag: tag)
    tag_group = Fabricate(:tag_group, tags: [tag, synonym])
    serialized = TagGroupSerializer.new(tag_group, root: false).as_json
    expect(serialized[:tags]).to contain_exactly({ id: tag.id, name: tag.name, slug: tag.slug })
  end

  it "uses slug_for_url for tags with empty slugs" do
    numeric_tag = Fabricate(:tag, name: "42")
    expect(numeric_tag.slug).to eq("")

    tag_group = Fabricate(:tag_group, tags: [numeric_tag])
    serialized = TagGroupSerializer.new(tag_group, root: false).as_json

    expect(serialized[:tags]).to contain_exactly(
      { id: numeric_tag.id, name: numeric_tag.name, slug: "#{numeric_tag.id}-tag" },
    )
  end

  it "uses slug_for_url for parent_tag with empty slug" do
    parent = Fabricate(:tag, name: "99")
    expect(parent.slug).to eq("")

    tag_group = Fabricate(:tag_group, parent_tag: parent)
    serialized = TagGroupSerializer.new(tag_group, root: false).as_json

    expect(serialized[:parent_tag]).to eq(
      [{ id: parent.id, name: parent.name, slug: "#{parent.id}-tag" }],
    )
  end
end
