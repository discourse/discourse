# frozen_string_literal: true

RSpec.describe Boards::CreateBoard do
  describe Boards::CreateBoard::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { Boards::CreateBoard.call(params:, raw_board_params: raw, **dependencies) }

    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)

    let(:raw) { { "name" => "New Board", "slug" => "new-board" } }
    let(:params) { raw }
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:raw) { { "slug" => "no-name" } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates the board" do
        expect { result }.to change { Boards::Board.count }.by(1)
        board = result[:board]
        expect(board.name).to eq("New Board")
        expect(board.slug).to eq("new-board")
        expect(board.created_by_id).to eq(manager.id)
      end

      it "creates mandatory ACLs when ACL params are omitted" do
        result

        manage_acl = AccessControlList.find_by!(target: result[:board], permission: "manage")
        expect(manage_acl.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
      end

      it "creates mandatory ACLs when ACL params are empty" do
        raw["acl"] = []

        result

        manage_acl = AccessControlList.find_by!(target: result[:board], permission: "manage")
        expect(manage_acl.allowed_group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
      end

      it "creates a board history" do
        expect { result }.to change { Boards::BoardHistory.count }.by(1)
        board = Boards::Board.last
        expect(board.history.first).to have_attributes(
          action: "board_created",
          acting_user_id: manager.id,
          board_id: board.id,
        )
      end

      context "with tag_names" do
        fab!(:admin)
        fab!(:existing_tag, :tag)

        let(:raw) do
          {
            "name" => "Tagged",
            "slug" => "tagged",
            "tag_names" => [existing_tag.name, "brand-new"],
          }
        end

        context "when the user can create tags" do
          let(:dependencies) { { guardian: admin.guardian } }

          it "resolves existing tags and creates new ones" do
            board = result[:board]
            expect(board.tag_ids).to contain_exactly(
              existing_tag.id,
              Tag.find_by(name: "brand-new").id,
            )
          end
        end

        it "fails when the user cannot create tags and a tag is missing" do
          expect(result).to be_failure
          expect(result["result.model.board"].exception).to be_a(Discourse::InvalidParameters)
        end

        context "when an existing tag is not visible to the user" do
          fab!(:restricted_tag, :tag)

          let(:raw) do
            { "name" => "Tagged", "slug" => "tagged", "tag_names" => [restricted_tag.name] }
          end

          before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tags: [restricted_tag]) }

          it "does not resolve the hidden tag" do
            expect(result).to be_failure
            expect(result["result.model.board"].exception).to be_a(Discourse::InvalidParameters)
          end
        end
      end

      context "with columns" do
        let(:raw) do
          {
            "name" => "With Columns",
            "columns" => [{ "title" => "Backlog" }, { "title" => "Done" }],
          }
        end

        it "creates columns" do
          result
          board = result[:board]
          expect(board.columns.count).to eq(2)
          expect(board.columns.order(:position).pluck(:title)).to eq(%w[Backlog Done])
        end

        context "when a column tag is not visible to the user" do
          fab!(:restricted_tag, :tag)

          let(:raw) do
            {
              "name" => "With Columns",
              "columns" => [{ "title" => "Restricted", "tag_name" => restricted_tag.name }],
            }
          end

          before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tags: [restricted_tag]) }

          it "does not resolve the hidden tag" do
            expect { result }.to raise_error(
              Discourse::InvalidParameters,
              I18n.t("boards.errors.unknown_tag_name", tag_name: restricted_tag.name),
            )
          end
        end
      end
    end
  end
end
