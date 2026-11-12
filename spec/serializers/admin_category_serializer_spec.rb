# frozen_string_literal: true

RSpec.describe AdminCategorySerializer do
  fab!(:admin)

  it "serializes admin category management data" do
    parent = Fabricate(:category, name: "Knowledge", slug: "knowledge")
    child = Fabricate(:category, name: "Guides", slug: "guides", parent_category: parent)

    serialized = described_class.new(child, scope: Guardian.new(admin), root: false).as_json

    expect(serialized).to include(
      id: child.id,
      badge_chain: [
        a_hash_including(id: parent.id, name: "Knowledge", parent_category_id: nil),
        a_hash_including(id: child.id, name: "Guides", parent_category_id: parent.id),
      ],
      category_types: [a_hash_including(id: :discussion, name: "Discussion")],
      description_text: child.description_text,
      read_restricted: false,
      topic_count: child.topic_count,
      edit_url: "/c/knowledge/guides/edit/general",
    )
  end
end
