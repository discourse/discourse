# frozen_string_literal: true

RSpec.describe Boards::UpdateCard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) do
      described_class.call(params:, raw_card_params: raw_card_params, **dependencies)
    end

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category)
    fab!(:tag)
    fab!(:topic) { Fabricate(:topic, category: category, user: writer) }
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board-uc", created_by_id: admin.id)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board
    end
    fab!(:col_todo) { board.columns.create!(title: "To Do", position: 0) }
    fab!(:col_done) { board.columns.create!(title: "Done", position: 1) }
    fab!(:col_recent) do
      board.columns.create!(title: "Recent", position: 2, default_sort: "recency")
    end

    let(:raw_card_params) { {} }
    let(:dependencies) { { guardian: writer.guardian } }

    before do
      enable_current_plugin
      write_group.add(writer)
      write_group.add(admin)
      read_group.add(reader)
    end

    context "when updating a floater card title" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Old",
          inline_onebox_data: {
            "url" => "https://example.com/old",
            "title" => "Old page title",
          },
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "title" => "New" } }
      let(:params) { { board_id: board.id, id: card.id, title: "New" } }

      it { is_expected.to run_successfully }

      it "updates the title" do
        result
        expect(card.reload.title).to eq("New")
        expect(card.inline_onebox_data).to be_nil
      end

      it "does not change column_changed_at" do
        previous_changed_at = 2.days.ago
        card.update_column(:column_changed_at, previous_changed_at)

        result
        expect(card.reload.column_changed_at.to_i).to eq(previous_changed_at.to_i)
      end

      it "logs a card edited history record" do
        expect { result }.to change {
          Boards::CardHistory.where(action: Boards::CardHistory.actions[:card_edited]).count
        }.by(1)
      end
    end

    context "when updating a floater card title to a URL" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Old",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:url) { "https://github.com/discourse/discourse/pull/42462" }
      let(:raw_card_params) { { "title" => url } }
      let(:params) { { board_id: board.id, id: card.id, title: url } }
      let(:onebox_data) do
        {
          "url" => url,
          "title" => "FEATURE: Add ProseMirror tab support",
          "css_class" => "--gh-status-approved",
        }
      end

      it "clears stale data without resolving inline" do
        card.update!(inline_onebox_data: onebox_data)
        Boards::Action::CardInlineOnebox.expects(:call).never

        result

        expect(card.reload.inline_onebox_data).to be_nil
      end
    end

    context "when updating a floater card without changing its title" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "https://example.com",
          inline_onebox_data: {
            "url" => "https://example.com",
            "title" => "Example Domain",
          },
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "notes" => "Updated notes" } }
      let(:params) { { board_id: board.id, id: card.id, notes: "Updated notes" } }

      it "preserves the existing inline onebox data without resolving it again" do
        Boards::Action::CardInlineOnebox.expects(:call).never
        result

        expect(card.reload.inline_onebox_data).to eq(
          "url" => "https://example.com",
          "title" => "Example Domain",
        )
      end
    end

    context "when moving a card between columns" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Move me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      it { is_expected.to run_successfully }

      it "moves the card to the new column" do
        result
        expect(card.reload.column_id).to eq(col_done.id)
      end

      it "updates column_changed_at" do
        previous_changed_at = 2.days.ago
        card.update_column(:column_changed_at, previous_changed_at)

        freeze_time do
          result
          expect(card.reload.column_changed_at.to_i).to eq(Time.current.to_i)
        end
      end

      it "records the original column id" do
        expect(result[:original_column_id]).to eq(col_todo.id)
      end

      it "creates a card history record" do
        expect { result }.to change {
          Boards::CardHistory.where(action: Boards::CardHistory.actions[:card_moved]).count
        }.by(1)
        expect(
          Boards::CardHistory.where(action: Boards::CardHistory.actions[:card_moved]).last.details,
        ).to eq("from" => col_todo.title, "to" => col_done.title)
      end
    end

    context "when moving a floater card between tagged columns" do
      fab!(:todo_tag, :tag) { Fabricate(:tag, name: "todo") }
      fab!(:done_tag, :tag) { Fabricate(:tag, name: "done") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Move tagged card",
          tag_ids: [todo_tag.id, unrelated_tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      before do
        col_todo.update!(tag_id: todo_tag.id)
        col_done.update!(tag_id: done_tag.id)
      end

      it "replaces the source column tag with the destination column tag" do
        result
        expect(card.reload.tag_ids).to contain_exactly(done_tag.id, unrelated_tag.id)
      end
    end

    context "when moving a floater card to an untagged column" do
      fab!(:todo_tag, :tag) { Fabricate(:tag, name: "todo") }
      fab!(:done_tag, :tag) { Fabricate(:tag, name: "done") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Move to untagged",
          tag_ids: [todo_tag.id, done_tag.id, unrelated_tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      before do
        col_todo.update!(tag_id: todo_tag.id)
        board.columns.create!(title: "Tagged sibling", position: 3, tag_id: done_tag.id)
      end

      it "removes board column tags and preserves unrelated tags" do
        result
        expect(card.reload.tag_ids).to contain_exactly(unrelated_tag.id)
      end
    end

    context "when reordering a floater card within the same tagged column" do
      fab!(:column_tag, :tag) { Fabricate(:tag, name: "same-column") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
      fab!(:other_card) do
        board.cards.create!(
          card_type: :floater,
          title: "Other",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Reorder me",
          tag_ids: [unrelated_tag.id],
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) do
        { "column_id" => col_todo.id.to_s, "after_card_id" => other_card.id.to_s }
      end
      let(:params) do
        { board_id: board.id, id: card.id, column_id: col_todo.id, after_card_id: other_card.id }
      end

      before { col_todo.update!(tag_id: column_tag.id) }

      it "does not apply column tag resolution" do
        result
        expect(card.reload.tag_ids).to contain_exactly(unrelated_tag.id)
      end
    end

    context "when editing tags on a floater card in a tagged column" do
      fab!(:column_tag, :tag) { Fabricate(:tag, name: "column-tag") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Edit tags",
          tag_ids: [column_tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "tag_ids" => [unrelated_tag.id] } }
      let(:params) { { board_id: board.id, id: card.id, tag_ids: [unrelated_tag.id] } }

      before { col_todo.update!(tag_id: column_tag.id) }

      it "re-applies the column tag" do
        result
        expect(card.reload.tag_ids).to contain_exactly(column_tag.id, unrelated_tag.id)
      end
    end

    context "when editing tags on a floater card to include a hidden tag" do
      fab!(:hidden_tag, :tag) { Fabricate(:tag, name: "staff-boards") }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Edit hidden tag",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "tag_ids" => [hidden_tag.id] } }
      let(:params) { { board_id: board.id, id: card.id, tag_ids: [hidden_tag.id] } }

      before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

      it "raises InvalidParameters" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when editing tags on a floater card to include a sibling column tag" do
      fab!(:column_tag, :tag) { Fabricate(:tag, name: "column-tag") }
      fab!(:sibling_tag, :tag) { Fabricate(:tag, name: "sibling-tag") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Edit sibling tag",
          tag_ids: [column_tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "tag_ids" => [sibling_tag.id, unrelated_tag.id] } }
      let(:params) do
        { board_id: board.id, id: card.id, tag_ids: [sibling_tag.id, unrelated_tag.id] }
      end

      before do
        col_todo.update!(tag_id: column_tag.id)
        col_done.update!(tag_id: sibling_tag.id)
      end

      it "removes the sibling column tag and preserves unrelated tags" do
        result
        expect(card.reload.tag_ids).to contain_exactly(column_tag.id, unrelated_tag.id)
      end
    end

    context "when preserving notes when not provided" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Keep details",
          notes: "Important note",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "title" => "Updated" } }
      let(:params) { { board_id: board.id, id: card.id, title: "Updated" } }

      it "preserves notes" do
        original_notes = card.notes
        result
        card.reload
        expect(card.notes).to eq(original_notes)
      end
    end

    context "when promoting a floater to a topic card" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          notes: "Some notes",
          tag_ids: [tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      it { is_expected.to run_successfully }

      it "converts the card to a topic card" do
        result_card = result[:card]
        expect(result_card).to be_topic
        expect(result_card.topic_id).to eq(topic.id)
        expect(result_card.title).to be_nil
        expect(result_card.notes).to be_nil
        expect(result_card.tag_ids).to eq([])
      end
    end

    context "when adopting an existing topic card" do
      fab!(:existing_topic_card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      it { is_expected.to run_successfully }

      it "sets original_column_id to the adopted card's original column" do
        expect(result[:original_column_id]).to eq(col_todo.id)
      end

      it "sets adopted_floater_id to the floater's id" do
        expect(result[:adopted_floater_id]).to eq(card.id)
      end

      it "destroys the floater" do
        result
        expect(Boards::Card.find_by(id: card.id)).to be_nil
      end
    end

    context "when adopting an existing topic card from an assigned floater" do
      fab!(:assignee, :user)
      fab!(:existing_topic_card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        assign_group = Fabricate(:group)
        SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
        assign_group.add(assignee)
        Fabricate(:post, topic: topic)
      end

      it "carries over the assignment to the topic" do
        result
        assignment = Assignment.find_by(target: topic, active: true)
        expect(assignment).to be_present
        expect(assignment.assigned_to).to eq(assignee)
      end
    end

    context "when moving a card to position 0 in a column" do
      fab!(:card_a) do
        board.cards.create!(
          card_type: :floater,
          title: "Card A",
          column_id: col_done.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card_b) do
        board.cards.create!(
          card_type: :floater,
          title: "Card B",
          column_id: col_done.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Move to first",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "column_id" => col_done.id.to_s, "after_card_id" => "" } }
      let(:params) { { board_id: board.id, id: card.id, column_id: col_done.id } }

      it { is_expected.to run_successfully }

      it "places the card first in the column" do
        result
        card.reload
        card_a.reload
        card_b.reload
        expect(card.column_id).to eq(col_done.id)
        expect(card.position).to be < card_a.position
        expect(card_a.position).to be < card_b.position
      end
    end

    context "when moving a card into a column sorted by recency" do
      fab!(:existing_card) do
        board.cards.create!(
          card_type: :floater,
          title: "Existing",
          column_id: col_recent.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Move to recent",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) do
        { "column_id" => col_recent.id.to_s, "after_card_id" => existing_card.id.to_s }
      end
      let(:params) do
        {
          board_id: board.id,
          id: card.id,
          column_id: col_recent.id,
          after_card_id: existing_card.id,
        }
      end

      it { is_expected.to run_successfully }

      it "ignores the requested position and places the card first" do
        result
        expect(card.reload.position).to be < existing_card.reload.position
      end
    end

    context "when reordering within a column sorted by recency" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "First",
          column_id: col_recent.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      fab!(:other_card) do
        board.cards.create!(
          card_type: :floater,
          title: "Second",
          column_id: col_recent.id,
          position: 1,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) do
        { "column_id" => col_recent.id.to_s, "after_card_id" => other_card.id.to_s }
      end
      let(:params) do
        { board_id: board.id, id: card.id, column_id: col_recent.id, after_card_id: other_card.id }
      end

      it "raises InvalidParameters" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
        expect(card.reload.position).to eq(0)
      end
    end

    context "when assigning a user to a floater card" do
      fab!(:assignee, :user)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Assign me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => assignee.username } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: assignee.username } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
      end

      it { is_expected.to run_successfully }

      it "assigns the user" do
        result
        expect(card.reload.assigned_to).to eq(assignee)
      end
    end

    context "when assigning a group to a floater card" do
      fab!(:assignee_group, :group)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Assign group",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => assignee_group.name } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: assignee_group.name } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
      end

      it { is_expected.to run_successfully }

      it "assigns the group" do
        result
        expect(card.reload.assigned_to).to eq(assignee_group)
      end
    end

    context "when unassigning a floater card" do
      fab!(:assignee, :user)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Unassign me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => "" } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: "" } }

      it { is_expected.to run_successfully }

      it "clears the assignment" do
        result
        expect(card.reload.assigned_to).to be_nil
      end
    end

    context "when assigning an unknown name" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Unknown assignee",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => "nonexistent_name" } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: "nonexistent_name" } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
      end

      it "raises InvalidParameters" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when assigning a group the user cannot see" do
      fab!(:hidden_group) { Fabricate(:group, visibility_level: Group.visibility_levels[:staff]) }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Hidden group",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => hidden_group.name } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: hidden_group.name } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        assign_group = Fabricate(:group)
        SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
        assign_group.add(writer)
      end

      it "raises InvalidParameters" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when writer without assign permissions tries to assign a floater" do
      fab!(:assignee, :user)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "No perms",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:raw_card_params) { { "assigned_to_name" => assignee.username } }
      let(:params) { { board_id: board.id, id: card.id, assigned_to_name: assignee.username } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
      end

      it "raises InvalidAccess" do
        expect { result }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when writer without assign permissions promotes an assigned floater" do
      fab!(:assignee, :user)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Assigned floater",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
      end

      it "raises InvalidAccess instead of silently dropping the assignment" do
        expect { result }.to raise_error(Discourse::InvalidAccess)
        expect(card.reload).to be_floater
      end
    end

    context "when promoting a floater with assignment to a topic card" do
      fab!(:assignee, :user)
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        assign_group = Fabricate(:group)
        SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
        assign_group.add(assignee)
        Fabricate(:post, topic: topic)
      end

      it { is_expected.to run_successfully }

      it "clears the card-level assignment on promotion" do
        result_card = result[:card]
        expect(result_card.assigned_to_id).to be_nil
        expect(result_card.assigned_to_type).to be_nil
      end

      it "assigns the card's assignee to the topic" do
        result
        assignment = Assignment.find_by(target: topic, active: true)
        expect(assignment).to be_present
        expect(assignment.assigned_to).to eq(assignee)
      end
    end

    context "when promoting an assigned floater and column has move_to_assigned" do
      fab!(:assignee, :user)
      fab!(:column_assignee, :user)
      fab!(:col_assigned) do
        board.columns.create!(
          title: "Assigned Col",
          position: 2,
          move_to_assigned: column_assignee.username,
        )
      end
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Column overrides",
          column_id: col_assigned.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        assign_group = Fabricate(:group)
        SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
        assign_group.add(column_assignee)
        Fabricate(:post, topic: topic)
      end

      it "uses the column's assignment rule instead of the card assignee" do
        result
        assignment = Assignment.find_by(target: topic, active: true)
        expect(assignment).to be_present
        expect(assignment.assigned_to).to eq(column_assignee)
      end
    end

    context "when promoting an assigned floater and column has move_to_assigned '*'" do
      fab!(:assignee, :user)
      fab!(:col_star) do
        board.columns.create!(title: "Star Col", position: 2, move_to_assigned: "*")
      end
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Star keeps card assignee",
          column_id: col_star.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        assign_group = Fabricate(:group)
        SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
        assign_group.add(assignee)
        Fabricate(:post, topic: topic)
      end

      it "carries over the card's assignee" do
        result
        assignment = Assignment.find_by(target: topic, active: true)
        expect(assignment).to be_present
        expect(assignment.assigned_to).to eq(assignee)
      end
    end

    context "when promoting a floater with group assignment" do
      fab!(:assignee_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Group assign",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee_group,
        )
      end

      let(:raw_card_params) { { "topic_id" => topic.id.to_s } }
      let(:params) { { board_id: board.id, id: card.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      before do
        skip("requires discourse-assign") unless defined?(::Assigner)
        SiteSetting.assign_enabled = true
        SiteSetting.assign_allowed_on_groups = assignee_group.id.to_s
        Fabricate(:post, topic: topic)
      end

      it "assigns the group to the topic" do
        result
        assignment = Assignment.find_by(target: topic, active: true)
        expect(assignment).to be_present
        expect(assignment.assigned_to).to eq(assignee_group)
      end
    end

    context "when card is not found" do
      let(:params) { { board_id: board.id, id: 0 } }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, id: 1 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot write" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Protected",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }
      let(:dependencies) { { guardian: reader.guardian } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
