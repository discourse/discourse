# frozen_string_literal: true

RSpec.describe Boards::Archive do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      Fabricate(:boards_board, slug: "roadmap", additional_manage_groups: [manage_group])
    end

    let(:params) { { board_id: board.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:messages) { MessageBus.track_publish("/boards/#{board.id}") { result } }

    before do
      enable_current_plugin
      freeze_time Time.utc(2026, 9, 10, 12)
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
      fab!(:acting_user, :user)

      before { manage_group.remove(acting_user) }

      it { is_expected.to fail_a_policy(:can_archive) }
    end

    context "when the board is already archived" do
      before { board.update!(archived: true) }

      it { is_expected.to fail_a_policy(:can_archive) }
    end

    context "when the actor has Manage permission outside the global management groups" do
      it "archives the board and records its previous slug and actor atomically" do
        expect(result).to run_successfully
        expect(board.reload).to have_attributes(
          archived: true,
          archived_at: Time.current,
          archived_by_id: acting_user.id,
          original_slug: "roadmap",
          slug: "roadmap-archived-20260910",
        )
        expect(board.history.sole).to have_attributes(
          action: "board_archived",
          acting_user_id: acting_user.id,
          details: {
            "previous_value" => "roadmap",
            "new_value" => "roadmap-archived-20260910",
          },
        )
      end

      it "does not publish to the archived board" do
        expect(messages).to be_empty
      end
    end

    context "when the original slug is at the normal length limit" do
      before { board.update!(slug: "a" * 255) }

      it "keeps the archive suffix without losing the original slug" do
        expect(result).to run_successfully
        expect(board.reload.slug).to eq("#{"a" * 255}-archived-20260910")
        expect(board.original_slug).to eq("a" * 255)
      end
    end

    context "when the original slug is encoded" do
      before do
        SiteSetting.slug_generation_method = "encoded"
        board.update!(slug: "路線")
      end

      it "preserves the stored encoding when appending the archive suffix" do
        original_slug = board.slug

        expect(result).to run_successfully
        expect(board.reload.slug).to eq("#{original_slug}-archived-20260910")
        expect(board.original_slug).to eq(original_slug)
      end
    end

    context "when the archive slug has already been used" do
      before { Fabricate(:boards_board, slug: "roadmap-archived-20260910") }

      it "uses an available numbered archive slug" do
        expect(result).to run_successfully
        expect(board.reload.slug).to eq("roadmap-archived-20260910-2")
      end
    end
  end
end
