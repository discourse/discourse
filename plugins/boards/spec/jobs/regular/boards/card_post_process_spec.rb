# frozen_string_literal: true

RSpec.describe Jobs::Boards::CardPostProcess do
  fab!(:admin)
  fab!(:viewer, :user)
  fab!(:viewer_group, :group)
  fab!(:board) do
    Fabricate(:boards_board, created_by: admin).tap do |board|
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [viewer_group],
      )
    end
  end
  fab!(:column) { Fabricate(:boards_column, board:) }
  fab!(:card) do
    Fabricate(
      :boards_card,
      board:,
      column:,
      title: "https://github.com/discourse/discourse/pull/42462",
      created_by: admin,
    )
  end

  before do
    enable_current_plugin
    viewer_group.add(viewer)
  end

  describe "#execute" do
    let(:onebox_data) do
      {
        "url" => card.title,
        "title" => "FEATURE: Add ProseMirror tab support",
        "css_class" => "--gh-status-approved",
      }
    end

    it "stores the inline onebox data without changing the card timestamp" do
      original_updated_at = card.updated_at
      Boards::Action::CardInlineOnebox.expects(:call).with(title: card.title).returns(onebox_data)

      described_class.new.execute(card_id: card.id, title: card.title)

      expect(card.reload.inline_onebox_data).to eq(onebox_data)
      expect(card.updated_at).to eq_time(original_updated_at)
    end

    it "publishes the updated card to users who can view the board" do
      Boards::Action::CardInlineOnebox.expects(:call).with(title: card.title).returns(onebox_data)

      messages =
        MessageBus.track_publish("/boards/#{board.id}") do
          described_class.new.execute(card_id: card.id, title: card.title)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.group_ids).to include(viewer_group.id)
      expect(messages.first.data).to include(type: "card_updated", client_id: nil)
      expect(messages.first.data.dig(:card, :inline_onebox_data)).to eq(onebox_data)
    end

    it "does nothing when the title has changed since the job was enqueued" do
      original_title = card.title
      card.update!(title: "A newer title")
      Boards::Action::CardInlineOnebox.expects(:call).never

      expect do
        described_class.new.execute(card_id: card.id, title: original_title)
      end.not_to change { card.reload.inline_onebox_data }
    end

    it "does not publish when resolving produces no data" do
      Boards::Action::CardInlineOnebox.expects(:call).with(title: card.title).returns(nil)

      messages =
        MessageBus.track_publish("/boards/#{board.id}") do
          described_class.new.execute(card_id: card.id, title: card.title)
        end

      expect(messages).to be_empty
      expect(card.reload.inline_onebox_data).to be_nil
    end

    it "does nothing for a topic-backed card" do
      topic_card = Fabricate(:boards_topic_card, board:, column:, created_by: admin)
      Boards::Action::CardInlineOnebox.expects(:call).never

      described_class.new.execute(card_id: topic_card.id, title: card.title)
    end

    it "does nothing for a title that is not a URL" do
      card.update!(title: "A regular card title")
      Boards::Action::CardInlineOnebox.expects(:call).with(title: card.title).returns(nil)

      described_class.new.execute(card_id: card.id, title: card.title)
    end
  end
end
