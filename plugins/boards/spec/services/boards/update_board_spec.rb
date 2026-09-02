# frozen_string_literal: true

RSpec.describe Boards::UpdateBoard do
  describe Boards::UpdateBoard::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { Boards::UpdateBoard.call(params:, raw_board_params: raw, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      board = Boards::Board.create!(name: "Old", slug: "old", created_by_id: admin.id)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "manage",
        groups: [manage_group],
      )
      board
    end
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }

    let(:raw) { { "name" => "Updated" } }
    let(:params) { raw.merge("id" => board.id) }
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
      manage_group.add(admin)
    end

    context "when contract is invalid" do
      let(:params) { { id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { "id" => 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the board" do
        result
        board.reload
        expect(board.name).to eq("Updated")
        expect(board.updated_by_id).to eq(manager.id)
      end

      it "tracks the board rename history" do
        result
        board.reload
        expect(board.history.first).to have_attributes(
          action: "board_renamed",
          acting_user_id: manager.id,
          board_id: board.id,
          details: {
            "previous_value" => "Old",
            "new_value" => "Updated",
          },
        )
      end

      it "replaces existing ACLs with mandatory ACLs when ACL params are empty" do
        raw["acl"] = []

        result

        manage_acl = AccessControlList.find_by!(target: board, permission: "manage")
        expect(manage_acl.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
      end

      it "does not delete topic cards on unconstrained boards" do
        let_raw = { "name" => "Updated", "columns" => [{ "id" => column.id, "title" => "Col" }] }
        let_params = let_raw.merge("id" => board.id)

        board.cards.create!(
          topic_id: Fabricate(:topic).id,
          card_type: :topic,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )

        expect {
          described_class.call(
            params: let_params,
            raw_board_params: let_raw,
            guardian: manager.guardian,
          )
        }.not_to change { board.cards.where(card_type: :topic).count }
      end

      context "with tag_names" do
        fab!(:existing_tag, :tag)

        let(:raw) { { "name" => "Updated", "tag_names" => [existing_tag.name, "brand-new"] } }

        it "resolves existing tags and creates new ones when the user can create tags" do
          described_class.call(params:, raw_board_params: raw, guardian: admin.guardian)
          board.reload
          expect(board.tag_ids).to contain_exactly(
            existing_tag.id,
            Tag.find_by(name: "brand-new").id,
          )
        end

        it "fails when the user cannot create tags and a tag is missing" do
          expect { result }.to raise_error(
            Discourse::InvalidParameters,
            I18n.t("boards.errors.unknown_tag_names", tag_names: "brand-new"),
          )
        end

        it "does not resolve a tag that is not visible to the user" do
          restricted_tag = Fabricate(:tag)
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tags: [restricted_tag])
          raw = { "name" => "Updated", "tag_names" => [restricted_tag.name] }

          expect {
            described_class.call(
              params: raw.merge("id" => board.id),
              raw_board_params: raw,
              **dependencies,
            )
          }.to raise_error(
            Discourse::InvalidParameters,
            I18n.t("boards.errors.unknown_tag_names", tag_names: restricted_tag.name),
          )
        end
      end

      context "with column changes" do
        let(:raw) do
          {
            "name" => "Updated",
            "columns" => [{ "id" => column.id, "title" => "Renamed" }, { "title" => "New Col" }],
          }
        end

        it "does not update columns" do
          result
          board.reload
          expect(board.columns.count).to eq(1)
          expect(column.reload.title).to eq("Col")
        end
      end

      context "with permission changes" do
        fab!(:new_group, :group)
        let(:raw) { { "acl" => [{ type: "group", id: new_group.id, permission: "manage" }] } }

        it "tracks the permission change history" do
          result
          board.reload
          expect(board.history.first).to have_attributes(
            action: "board_permissions_changed",
            acting_user_id: manager.id,
            board_id: board.id,
            details: {
              "previous_permissions" => {
                "manage" => {
                  "group_ids" => [manage_group.id],
                  "user_ids" => [],
                },
              },
              "new_permissions" => {
                "manage" => {
                  "group_ids" => [new_group.id, Group::AUTO_GROUPS[:admins]],
                  "user_ids" => [],
                },
              },
            },
          )
        end
      end

      context "with constraint changes" do
        fab!(:category)
        fab!(:tag)
        let(:raw) { { "category_ids" => [category.id], "tag_ids" => [tag.id] } }

        it "tracks the constraint change history" do
          result
          board.reload
          expect(board.history.first).to have_attributes(
            action: "board_constraints_changed",
            acting_user_id: manager.id,
            board_id: board.id,
            details: {
              "previous_category_ids" => [],
              "new_category_ids" => [category.id],
              "previous_tag_ids" => [],
              "new_tag_ids" => [tag.id],
            },
          )
        end
      end
    end
  end
end
