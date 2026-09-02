# frozen_string_literal: true

RSpec.describe Boards::CardSerializer do
  fab!(:admin)
  fab!(:viewer, :user)
  fab!(:allowed_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: allowed_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:column) { Fabricate(:boards_column, board:) }
  fab!(:card) do
    Fabricate(
      :boards_card,
      board:,
      column:,
      card_type: :topic,
      topic: private_topic,
      created_by: admin,
    )
  end

  before { enable_current_plugin }

  it "omits topic details when the scoped user cannot see the topic" do
    payload = described_class.new(card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload).to include(topic_id: private_topic.id)
    expect(payload).not_to have_key(:topic)
  end

  it "includes topic details when the scoped user can see the topic" do
    allowed_group.add(viewer)

    payload = described_class.new(card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload[:topic]).to include(title: private_topic.title, slug: private_topic.slug)
  end

  it "serializes Unicode titles for floater cards" do
    floater_card =
      Fabricate(
        :boards_card,
        board:,
        column:,
        card_type: :floater,
        title: "Launch :rocket:",
        created_by: admin,
      )

    payload = described_class.new(floater_card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload).to include(title: "Launch :rocket:", unicode_title: "Launch 🚀")
  end

  it "serializes inline onebox data for floater cards" do
    onebox_data = {
      "url" => "https://github.com/discourse/discourse/pull/42462",
      "title" => "FEATURE: Add ProseMirror tab support",
      "css_class" => "--gh-status-approved",
    }
    floater_card =
      Fabricate(
        :boards_card,
        board:,
        column:,
        card_type: :floater,
        title: onebox_data["url"],
        inline_onebox_data: onebox_data,
        created_by: admin,
      )

    payload = described_class.new(floater_card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload[:inline_onebox_data]).to eq(onebox_data)
  end

  it "omits floater tag metadata the scoped user cannot see" do
    visible_tag = Fabricate(:tag, name: "visible-boards")
    hidden_tag = Fabricate(:tag, name: "staff-boards")
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    floater_card =
      Fabricate(
        :boards_card,
        board:,
        column:,
        card_type: :floater,
        title: "Tagged floater",
        tag_ids: [visible_tag.id, hidden_tag.id],
        created_by: admin,
      )

    payload = described_class.new(floater_card, root: false, scope: Guardian.new(viewer)).as_json

    expect(payload[:tag_ids]).to contain_exactly(visible_tag.id)
    expect(payload[:tags].map { |tag| tag[:name] }).to contain_exactly(visible_tag.name)
  end
end
