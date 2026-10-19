# frozen_string_literal: true

RSpec.describe Boards::CreateColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
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

    let(:params) do
      { board_id: board.id, title: "Backlog", color: "1A2B3C", default_sort: "priority" }
    end
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:params) { { board_id: board.id, title: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, title: "Backlog" } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a column at the next position" do
        board.columns.create!(title: "Existing", position: 0)

        expect { result }.to change { board.columns.count }.by(1)
        expect(result[:column]).to have_attributes(title: "Backlog", color: "1A2B3C", position: 1)
      end

      it "tracks the column added history" do
        result

        expect(board.history.last).to have_attributes(
          action: "column_added",
          acting_user_id: manager.id,
          board_id: board.id,
          column_id: result[:column].id,
          details: {
            "title" => "Backlog",
            "color" => "1A2B3C",
            "tag_id" => nil,
            "move_to_category_id" => nil,
            "move_to_assigned" => nil,
            "move_to_status" => nil,
          },
        )
      end

      it "publishes a board_updated event" do
        messages = MessageBus.track_publish("/boards/#{board.id}") { result }

        expect(messages.map { |message| message.data[:type] }).to include("board_updated")
      end

      context "with a tag name" do
        fab!(:tag)

        let(:params) { { board_id: board.id, title: "Tagged", tag_name: tag.name } }

        it "assigns the visible tag" do
          result

          expect(result[:column].reload.tag_id).to eq(tag.id)
        end

        it "rejects duplicate sibling tags" do
          board.columns.create!(title: "Existing", position: 0, tag_id: tag.id)

          expect(result).to fail_to_find_a_model(:column)
          expect(result["result.model.column"].exception).to be_a(Discourse::InvalidParameters)
          expect(result["result.model.column"].exception.message).to eq(
            I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name),
          )
        end
      end

      context "when a tag is not visible to the user" do
        fab!(:restricted_tag, :tag)

        let(:params) { { board_id: board.id, title: "Hidden", tag_name: restricted_tag.name } }

        before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tags: [restricted_tag]) }

        it "does not resolve the hidden tag" do
          expect(result).to fail_to_find_a_model(:column)
          expect(result["result.model.column"].exception).to be_a(Discourse::InvalidParameters)
          expect(result["result.model.column"].exception.message).to eq(
            I18n.t("boards.errors.unknown_tag_name", tag_name: restricted_tag.name),
          )
        end
      end

      context "when default sort is invalid" do
        let(:params) { { board_id: board.id, title: "Broken", default_sort: "random" } }

        it "raises an invalid parameters error" do
          expect(result).to fail_to_find_a_model(:column)
          expect(result["result.model.column"].exception).to be_a(Discourse::InvalidParameters)
        end
      end

      context "when loose-card tag enforcement fails" do
        fab!(:tag)

        let(:params) { { board_id: board.id, title: "Tagged", tag_name: tag.name } }

        before do
          allow(Boards::LooseCardTagMutator).to receive(:apply_to_column!).and_raise(
            ActiveRecord::RecordInvalid,
          )
        end

        it "rolls back the created column" do
          expect(result).to fail_to_find_a_model(:column)
          expect(result["result.model.column"].exception).to be_a(ActiveRecord::RecordInvalid)
          expect(board.columns.where(title: "Tagged")).to be_empty
        end
      end
    end
  end
end
