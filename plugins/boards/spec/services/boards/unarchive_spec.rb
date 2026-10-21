# frozen_string_literal: true

RSpec.describe Boards::Unarchive do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      Fabricate(
        :boards_board,
        slug: "roadmap-archived-20260910",
        original_slug: "roadmap",
        archived: true,
        archived_at: Time.utc(2026, 9, 10),
        archived_by: acting_user,
        additional_manage_groups: [manage_group],
      )
    end

    let(:params) { { board_id: board.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      enable_current_plugin
      manage_group.add(acting_user)
      SiteSetting.boards_manage_board_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    end

    context "when the contract is invalid" do
      let(:params) { { board_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the board is missing" do
      let(:params) { { board_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when the actor has no Manage permission" do
      before { manage_group.remove(acting_user) }

      it { is_expected.to fail_a_policy(:can_unarchive) }
    end

    context "when the board is open" do
      before { board.update!(archived: false) }

      it { is_expected.to fail_a_policy(:can_unarchive) }
    end

    context "when the original slug is available" do
      it "restores the slug and clears archive metadata for a manager outside global groups" do
        expect(result).to run_successfully
        expect(board.reload).to have_attributes(
          archived: false,
          archived_at: nil,
          archived_by_id: nil,
          original_slug: nil,
          slug: "roadmap",
        )
        expect(board.history.sole).to have_attributes(
          action: "board_unarchived",
          acting_user_id: acting_user.id,
          details: {
            "previous_value" => "roadmap-archived-20260910",
            "new_value" => "roadmap",
          },
        )
      end
    end

    context "when the original slug is at the normal length limit" do
      before { board.update!(original_slug: "a" * 255) }

      it "restores the entire original slug" do
        expect(result).to run_successfully
        expect(board.reload.slug).to eq("a" * 255)
      end
    end

    context "when the original slug is encoded" do
      before do
        SiteSetting.slug_generation_method = "encoded"
        board.update!(original_slug: "%E8%B7%AF%E7%B7%9A")
      end

      it "restores the original encoding unchanged" do
        expect(result).to run_successfully
        expect(board.reload.slug).to eq("%E8%B7%AF%E7%B7%9A")
      end
    end

    context "when the original slug is occupied" do
      before { Fabricate(:boards_board, slug: "roadmap") }

      it "preserves archive metadata and history when no replacement is supplied" do
        expect(result).to fail_with_exception(ActiveRecord::RecordInvalid)
        expect(board.reload).to have_attributes(
          archived: true,
          slug: "roadmap-archived-20260910",
          original_slug: "roadmap",
          archived_by_id: acting_user.id,
        )
        expect(board.history).to be_empty
      end
    end

    context "when a replacement slug is supplied" do
      let(:params) { { board_id: board.id, slug: "New roadmap" } }

      before { Fabricate(:boards_board, slug: "roadmap") }

      it "normalizes the replacement slug and records it in history" do
        expect(result).to run_successfully
        expect(board.reload.slug).to eq("new-roadmap")
        expect(board.history.sole.details["new_value"]).to eq("new-roadmap")
      end
    end

    context "when a replacement slug is also occupied" do
      let(:params) { { board_id: board.id, slug: "other" } }

      before { Fabricate(:boards_board, slug: "other") }

      it "keeps the board archived without recording an unarchive" do
        expect(result).to fail_with_exception(ActiveRecord::RecordInvalid)
        expect(board.reload).to be_archived
        expect(board.history).to be_empty
      end
    end
  end
end
