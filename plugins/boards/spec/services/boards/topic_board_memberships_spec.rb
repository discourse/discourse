# frozen_string_literal: true

RSpec.describe Boards::TopicBoardMemberships do
  subject(:result) { described_class.call(guardian:, options: { topics: }) }

  fab!(:admin)
  fab!(:reader, :user)
  fab!(:outsider, :user)
  fab!(:read_group, :group)
  fab!(:topic)
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:column) { Fabricate(:boards_column, board:) }
  fab!(:card) { Fabricate(:boards_topic_card, board:, column:, topic:) }

  let(:topics) { [topic] }
  let(:guardian) { reader.guardian }

  before do
    enable_current_plugin
    read_group.add(reader)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "view",
      groups: [read_group],
    )
  end

  it { is_expected.to run_successfully }

  it "returns readable cards grouped by topic and board" do
    expect(result[:cards_map]).to eq(topic.id => { board.id => [card] })
  end

  context "when the topic has no board memberships" do
    fab!(:topic_without_memberships, :topic)

    let(:topics) { [topic_without_memberships] }

    it { is_expected.to run_successfully }

    it "returns an empty membership list" do
      expect(result[:single_topic_memberships]).to eq([])
    end
  end

  context "when the board is not readable" do
    let(:guardian) { outsider.guardian }

    it "does not return the board's cards" do
      expect(result[:cards_map]).to be_empty
    end
  end

  context "when the board is readable anonymously" do
    before do
      AccessControlList.find_by!(target: board, permission: "view").update!(
        allowed_group_ids: [read_group.id, Group::AUTO_GROUPS[:anonymous_users]],
      )
    end

    let(:guardian) { Guardian.new }

    it "returns the board's cards" do
      expect(result[:cards_map]).to eq(topic.id => { board.id => [card] })
    end
  end
end
