# frozen_string_literal: true

RSpec.describe Boards::UpdateColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to allow_value(nil, "f0a", "1A2B3C").for(:color) }
    it { is_expected.not_to allow_value("#1A2B3C", "purple").for(:color) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      Fabricate(:boards_board, created_by: admin, additional_manage_groups: [manage_group])
    end
    fab!(:column) { board.columns.create!(title: "Old", position: 0) }

    let(:params) do
      { board_id: board.id, id: column.id, title: "New", color: "1A2B3C", default_sort: "priority" }
    end
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:params) { { board_id: board.id, id: column.id, title: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, id: column.id, title: "New" } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, id: 0, title: "New" } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the column without changing position" do
        result

        expect(column.reload).to have_attributes(title: "New", color: "1A2B3C", position: 0)
      end

      it "tracks the column renamed history" do
        result

        expect(board.history.find_by(action: :column_renamed)).to have_attributes(
          action: "column_renamed",
          acting_user_id: manager.id,
          board_id: board.id,
          column_id: column.id,
          details: {
            "previous_value" => "Old",
            "new_value" => "New",
          },
        )
      end

      context "with non-title changes" do
        let(:params) do
          {
            board_id: board.id,
            id: column.id,
            title: "Old",
            icon: "check",
            color: "f0a",
            default_sort: "recency",
          }
        end

        it "tracks the column edited history" do
          result

          expect(board.history.last).to have_attributes(
            action: "column_edited",
            acting_user_id: manager.id,
            board_id: board.id,
            column_id: column.id,
            details: {
              "previous_values" => {
                "icon" => nil,
                "color" => nil,
                "default_sort" => "priority",
              },
              "new_values" => {
                "icon" => "check",
                "color" => "f0a",
                "default_sort" => "recency",
              },
            },
          )
        end
      end

      context "with title and non-title changes" do
        let(:params) do
          { board_id: board.id, id: column.id, title: "New", default_sort: "recency" }
        end

        it "tracks the renamed and edited histories separately" do
          result

          expect(board.history.map(&:action)).to eq(%w[column_renamed column_edited])
        end
      end

      it "publishes a board_updated event" do
        messages = MessageBus.track_publish("/boards/#{board.id}") { result }

        expect(messages.map { |message| message.data[:type] }).to include("board_updated")
      end

      context "with a tag name" do
        fab!(:tag)

        let(:params) { { board_id: board.id, id: column.id, title: "New", tag_name: tag.name } }

        it "assigns the visible tag and updates loose cards" do
          card =
            board.cards.create!(
              card_type: :floater,
              title: "Loose",
              column_id: column.id,
              position: 0,
              created_by_id: admin.id,
            )

          result

          expect(column.reload.tag_id).to eq(tag.id)
          expect(card.reload.tag_ids).to contain_exactly(tag.id)
        end

        it "rejects duplicate sibling tags" do
          board.columns.create!(title: "Sibling", position: 1, tag_id: tag.id)

          expect { result }.to raise_error(
            Discourse::InvalidParameters,
            I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name),
          )
        end
      end

      context "when a tag is not visible to the user" do
        fab!(:restricted_tag, :tag)

        let(:params) do
          { board_id: board.id, id: column.id, title: "Hidden", tag_name: restricted_tag.name }
        end

        before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tags: [restricted_tag]) }

        it "does not resolve the hidden tag" do
          expect { result }.to raise_error(
            Discourse::InvalidParameters,
            I18n.t("boards.errors.unknown_tag_name", tag_name: restricted_tag.name),
          )
        end
      end

      context "when default sort is invalid" do
        let(:params) { { board_id: board.id, id: column.id, title: "Broken", default_sort: "x" } }

        it "raises an invalid parameters error" do
          expect { result }.to raise_error(Discourse::InvalidParameters)
        end
      end

      context "when loose-card tag enforcement fails" do
        fab!(:tag)

        let(:params) { { board_id: board.id, id: column.id, title: "New", tag_name: tag.name } }

        before do
          allow(Boards::LooseCardTagMutator).to receive(:apply_to_column!).and_raise(
            ActiveRecord::RecordInvalid,
          )
        end

        it "rolls back the column update" do
          expect { result }.to raise_error(ActiveRecord::RecordInvalid)
          expect(column.reload.tag_id).to be_nil
        end
      end
    end
  end
end
