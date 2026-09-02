# frozen_string_literal: true

RSpec.describe Boards::BoardSerializer do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:writer, :user)
  fab!(:manage_group, :group)
  fab!(:write_group, :group)
  fab!(:category)
  fab!(:visible_tag) { Fabricate(:tag, name: "visible-boards") }
  fab!(:alpha_tag) { Fabricate(:tag, name: "alpha-boards") }
  fab!(:hidden_tag) { Fabricate(:tag, name: "staff-boards") }

  before do
    enable_current_plugin
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
    write_group.add(writer)
  end

  it "serializes core board attributes and nested columns" do
    board =
      Fabricate(
        :boards_board,
        name: "Sprint",
        slug: "sprint",
        category_ids: [category.id],
        tag_ids: [visible_tag.id],
        require_confirmation: true,
        show_tags: true,
        card_style: "detailed",
        show_topic_thumbnail: true,
        created_by: admin,
      )
    Fabricate(:boards_column, board:, title: "Backlog", position: 0, tag_id: visible_tag.id)

    payload =
      described_class.new(
        board,
        root: false,
        scope: Guardian.new(admin),
        tag_name_map: {
          visible_tag.id => visible_tag.name,
        },
      ).as_json

    expect(payload).to include(
      id: board.id,
      name: "Sprint",
      slug: "sprint",
      category_ids: [category.id],
      tag_ids: [visible_tag.id],
      tag_names: [visible_tag.name],
      anonymous_can_read: board.anonymous_can_read?,
      require_confirmation: true,
      show_tags: true,
      card_style: "detailed",
      show_topic_thumbnail: true,
      acl: nil,
    )
    expect(payload[:columns].first).to include(title: "Backlog", tag_id: visible_tag.id)
  end

  it "serializes a Unicode board name when the name contains emoji codes" do
    board = Fabricate(:boards_board, name: "Launch :rocket:", created_by: admin)

    payload =
      described_class.new(board, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json

    expect(payload).to include(name: "Launch :rocket:", unicode_name: "Launch 🚀")
  end

  it "serializes permission booleans from the scoped guardian" do
    managed_board =
      Fabricate(:boards_board, created_by: admin, additional_manage_groups: [manage_group])
    writable_board = Fabricate(:boards_board, created_by: admin)
    Fabricate(
      :access_control_list_with_groups,
      target: writable_board,
      permission: "edit",
      groups: [write_group],
    )

    manager_payload =
      described_class.new(managed_board, root: false, scope: Guardian.new(manager)).as_json
    writer_payload =
      described_class.new(writable_board, root: false, scope: Guardian.new(writer)).as_json

    expect(manager_payload).to include(can_manage: true)
    expect(writer_payload).to include(can_write: true, can_manage: false)
  end

  it "serializes the creator username and avatar template" do
    board = Fabricate(:boards_board, created_by: admin)

    payload =
      described_class.new(board, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json

    expect(payload[:created_by]).to eq(
      username: admin.username,
      avatar_template: admin.avatar_template,
    )
  end

  it "filters board tags through the tag name map and sorts tag names" do
    board =
      Fabricate(
        :boards_board,
        created_by: admin,
        tag_ids: [visible_tag.id, hidden_tag.id, alpha_tag.id],
      )

    payload =
      described_class.new(
        board,
        root: false,
        scope: Guardian.new(admin),
        tag_name_map: {
          visible_tag.id => visible_tag.name,
          alpha_tag.id => alpha_tag.name,
        },
      ).as_json

    expect(payload[:tag_ids]).to contain_exactly(visible_tag.id, alpha_tag.id)
    expect(payload[:tag_names]).to eq([alpha_tag.name, visible_tag.name])
  end

  it "includes acl only when requested" do
    board = Fabricate(:boards_board, created_by: admin, additional_manage_groups: [manage_group])

    default_payload =
      described_class.new(board, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json
    acl_payload =
      described_class.new(board, root: false, scope: Guardian.new(admin), include_acl: true).as_json

    expect(default_payload).to include(acl: nil)
    expect(acl_payload[:acl]).to eq(AccessControlList.where(target: board).flattened_list)
  end
end
