# frozen_string_literal: true

RSpec.describe Boards::DestroyCard do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic_with_op, user: admin) }
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:column) { Fabricate(:boards_column, board: board) }
  fab!(:card) { Fabricate(:boards_topic_card, board: board, column: column, topic: topic) }

  before do
    SiteSetting.capybara_enabled = true
    SiteSetting.boards_enabled = true
  end

  around { |example| stub_const(CodexBoardBot, :BOARD_ID, board.id) { example.run } }

  describe ".call" do
    subject(:result) do
      described_class.call(
        guardian: acting_user.guardian,
        params: {
          board_id: board.id,
          id: card.id,
        },
      )
    end

    fab!(:acting_user, :admin)

    it "deletes the card and closes its topic" do
      expect(result).to be_success
      expect(Boards::Card.exists?(card.id)).to eq(false)
      expect(topic.reload).to be_closed
      expect(topic.posts.where(action_code: "closed.enabled").count).to eq(1)
    end

    context "when a board writer deletes an already closed topic card" do
      fab!(:acting_user, :user)

      it "keeps the topic closed without a duplicate closing post" do
        topic.update_status("closed", true, admin)
        Fabricate(
          :access_control_list_with_users,
          target: board,
          permission: "edit",
          users: [acting_user],
        )
        expect { result }.not_to change { topic.posts.where(action_code: "closed.enabled").count }
        expect(result).to be_success
        expect(topic.reload).to be_closed
      end
    end

    it "keeps topics open on other boards" do
      stub_const(CodexBoardBot, :BOARD_ID, board.id + 1) { expect(result).to be_success }
      expect(topic.reload).not_to be_closed
    end

    it "keeps topics open when the plugin is disabled" do
      SiteSetting.capybara_enabled = false
      expect(result).to be_success
      expect(topic.reload).not_to be_closed
    end

    it "keeps topics open in production" do
      Rails.env.stubs(:production?).returns(true)
      expect(result).to be_success
      expect(topic.reload).not_to be_closed
    end

    it "deletes regular cards without changing a topic" do
      card.update!(topic: nil, card_type: :floater, title: "A regular card")
      expect(result).to be_success
      expect(topic.reload).not_to be_closed
    end

    context "when the actor is an ordinary user" do
      fab!(:acting_user, :user)

      it "keeps the card and topic unchanged when board access is denied" do
        expect(result).to fail_a_policy(:can_write)
        expect(Boards::Card.exists?(card.id)).to eq(true)
        expect(topic.reload).not_to be_closed
      end

      it "requires permission to close the topic even with board editing access" do
        Fabricate(
          :access_control_list_with_users,
          target: board,
          permission: "edit",
          users: [acting_user],
        )
        expect { result }.to raise_error(Discourse::InvalidAccess)
        expect(Boards::Card.exists?(card.id)).to eq(true)
        expect(topic.reload).not_to be_closed
      end
    end

    it "rolls back the deletion when closing fails" do
      Topic.any_instance.stubs(:update_status).raises(ActiveRecord::RecordInvalid.new(topic))
      expect { result }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Boards::Card.exists?(card.id)).to eq(true)
      expect(topic.reload).not_to be_closed
    end
  end
end
