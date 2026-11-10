# frozen_string_literal: true

RSpec.describe Boards::TopicMutator do
  fab!(:admin)
  fab!(:user, :trust_level_1)
  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:target_category) { Fabricate(:category, name: "Done") }
  fab!(:post) do
    Fabricate(:post, user: user, topic: Fabricate(:topic, category: category, user: user))
  end
  fab!(:topic) { post.topic }

  before { enable_current_plugin }

  fab!(:board) do
    Boards::Board.create!(name: "Test", slug: "test-mutator", created_by_id: admin.id)
  end

  describe ".apply!" do
    it "raises InvalidAccess when user is nil" do
      column = board.columns.create!(title: "Col", position: 0, move_to_status: "closed")

      expect {
        described_class.apply!(topic: topic, column: column, guardian: Guardian.new(nil))
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises InvalidAccess when user cannot edit the topic" do
      column = board.columns.create!(title: "Col", position: 0, move_to_status: "closed")
      other_user = Fabricate(:user)

      topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

      expect {
        described_class.apply!(topic: topic, column: column, guardian: other_user.guardian)
      }.to raise_error(Discourse::InvalidAccess)
    end

    context "with tag_id" do
      before { SiteSetting.tagging_enabled = true }

      it "adds the configured tag to the topic" do
        tag = Fabricate(:tag, name: "in-progress")
        column = board.columns.create!(title: "In Progress", position: 0, tag_id: tag.id)

        described_class.apply!(topic: topic, column: column, guardian: admin.guardian)

        expect(topic.reload.tags.map(&:name)).to include("in-progress")
      end

      it "preserves existing tags" do
        existing_tag = Fabricate(:tag, name: "existing")
        new_tag = Fabricate(:tag, name: "new-tag")
        topic.tags << existing_tag

        column = board.columns.create!(title: "Col", position: 0, tag_id: new_tag.id)

        described_class.apply!(topic: topic, column: column, guardian: admin.guardian)

        tag_names = topic.reload.tags.map(&:name)
        expect(tag_names).to include("existing")
        expect(tag_names).to include("new-tag")
      end

      it "removes tags from other columns on the same board" do
        todo_tag = Fabricate(:tag, name: "todo")
        doing_tag = Fabricate(:tag, name: "doing")
        done_tag = Fabricate(:tag, name: "done")
        unrelated_tag = Fabricate(:tag, name: "unrelated")

        board.columns.create!(title: "Todo", position: 0, tag_id: todo_tag.id)
        doing_column = board.columns.create!(title: "Doing", position: 1, tag_id: doing_tag.id)
        board.columns.create!(title: "Done", position: 2, tag_id: done_tag.id)

        topic.tags = [todo_tag, unrelated_tag]

        described_class.apply!(topic: topic, column: doing_column, guardian: admin.guardian)

        tag_names = topic.reload.tags.map(&:name)
        expect(tag_names).to contain_exactly("doing", "unrelated")
      end

      it "does nothing when tag_id is nil" do
        column = board.columns.create!(title: "Col", position: 0, tag_id: nil)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to change { topic.reload.tags.count }
      end

      it "removes the source column tag when moving to a column with no tag" do
        ford_tag = Fabricate(:tag, name: "ford")
        board.columns.create!(title: "Ford", position: 0, tag_id: ford_tag.id)
        catchall_column = board.columns.create!(title: "Backlog", position: 1)

        topic.tags = [ford_tag]

        described_class.apply!(topic: topic, column: catchall_column, guardian: admin.guardian)

        expect(topic.reload.tags.map(&:name)).not_to include("ford")
      end

      it "removes only sibling column tags when moving to a column with no tag" do
        ford_tag = Fabricate(:tag, name: "ford-tag")
        chevy_tag = Fabricate(:tag, name: "chevy-tag")
        unrelated_tag = Fabricate(:tag, name: "unrelated-tag")

        board.columns.create!(title: "Ford", position: 0, tag_id: ford_tag.id)
        board.columns.create!(title: "Chevy", position: 1, tag_id: chevy_tag.id)
        catchall_column = board.columns.create!(title: "Backlog", position: 2)

        topic.tags = [ford_tag, unrelated_tag]

        described_class.apply!(topic: topic, column: catchall_column, guardian: admin.guardian)

        expect(topic.reload.tags.map(&:name)).to contain_exactly("unrelated-tag")
      end
    end

    context "with move_to_category_id" do
      it "moves the topic to the target category" do
        column =
          board.columns.create!(title: "Done", position: 0, move_to_category_id: target_category.id)

        described_class.apply!(topic: topic, column: column, guardian: admin.guardian)

        expect(topic.reload.category_id).to eq(target_category.id)
      end

      it "raises NotFound for a missing category" do
        doomed_category = Fabricate(:category)
        column =
          board.columns.create!(title: "Col", position: 0, move_to_category_id: doomed_category.id)
        doomed_category.destroy!

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.to raise_error(Discourse::NotFound)
      end

      it "does nothing when move_to_category_id is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_category_id: nil)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to change { topic.reload.category_id }
      end
    end

    context "with move_to_status" do
      it "raises InvalidAccess when a user with edit access cannot close the topic" do
        column = board.columns.create!(title: "Closed", position: 0, move_to_status: "closed")

        expect(Guardian.new(user).can_edit?(topic)).to eq(true)
        expect(Guardian.new(user).can_close_topic?(topic)).to eq(false)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: user.guardian)
        }.to raise_error(Discourse::InvalidAccess)
        expect(topic.reload.closed).to eq(false)
      end

      it "raises InvalidAccess when a user with edit access cannot open the topic" do
        topic.update_status("closed", true, admin)
        column = board.columns.create!(title: "Open", position: 0, move_to_status: "open")

        expect(Guardian.new(user).can_edit?(topic)).to eq(true)
        expect(Guardian.new(user).can_open_topic?(topic)).to eq(false)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: user.guardian)
        }.to raise_error(Discourse::InvalidAccess)
        expect(topic.reload.closed).to eq(true)
      end

      it "closes the topic when status is 'closed'" do
        column = board.columns.create!(title: "Closed", position: 0, move_to_status: "closed")

        described_class.apply!(topic: topic, column: column, guardian: admin.guardian)

        expect(topic.reload.closed).to eq(true)
      end

      it "opens the topic when status is not 'closed'" do
        topic.update_status("closed", true, admin)
        expect(topic.reload.closed).to eq(true)

        column = board.columns.create!(title: "Open", position: 0, move_to_status: "open")

        described_class.apply!(topic: topic, column: column, guardian: admin.guardian)

        expect(topic.reload.closed).to eq(false)
      end

      it "does nothing when move_to_status is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_status: "")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to change { topic.reload.closed }
      end
    end

    context "with move_to_assigned" do
      it "raises InvalidAccess when a user with edit access cannot change assignment" do
        skip("requires discourse-assign") unless defined?(Assignment)

        SiteSetting.assign_enabled = true
        SiteSetting.assign_allowed_on_groups = ""
        Assignment.create!(
          target: topic,
          topic_id: topic.id,
          assigned_to: admin,
          assigned_by_user: admin,
          active: true,
        )
        column = board.columns.create!(title: "Unassigned", position: 0, move_to_assigned: "nobody")

        expect(Guardian.new(user).can_edit?(topic)).to eq(true)
        expect(Guardian.new(user).can_assign?(topic)).to eq(false)

        expect {
          described_class.apply!(topic: topic, column: column, guardian: user.guardian)
        }.to raise_error(Discourse::InvalidAccess)
        expect(topic.reload.assignment).to be_present
      end

      it "does nothing when Assigner is not defined" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "someone")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to raise_error
      end

      it "does nothing when move_to_assigned is blank" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to raise_error
      end

      it "does nothing when move_to_assigned is '*'" do
        column = board.columns.create!(title: "Col", position: 0, move_to_assigned: "*")

        expect {
          described_class.apply!(topic: topic, column: column, guardian: admin.guardian)
        }.not_to raise_error
      end
    end
  end
end
