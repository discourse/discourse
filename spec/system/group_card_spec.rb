# frozen_string_literal: true

describe "Group Card", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:members) { Fabricate.times(12, :user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:group) { Fabricate(:public_group, users: members) }
  let(:mention) { "@#{group.name}" }
  let(:post_with_mention) do
    PostCreator.create!(current_user, topic_id: topic.id, raw: "Hello #{mention}")
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:group_card) { PageObjects::Components::GroupCard.new }

  before do
    Jobs.run_immediately!
    sign_in(current_user)
  end

  context "when joining/leaving a group" do
    it "shows only highlighted members" do
      topic_page.visit_topic(topic, post_number: post_with_mention.post_number)
      topic_page.click_mention(post_with_mention, mention)

      expect(group_card).to have_highlighted_member_count_of(
        PageObjects::Components::GroupCard::MAX_MEMBER_HIGHLIGHT_COUNT,
      )

      group_card.click_join_button

      expect(group_card).to have_leave_button

      group.reload

      expect(group.users).to include(current_user)
      expect(group_card).to have_highlighted_member_count_of(
        PageObjects::Components::GroupCard::MAX_MEMBER_HIGHLIGHT_COUNT,
      )

      group_card.click_leave_button

      expect(group_card).to have_join_button

      group.reload

      expect(group.users).not_to include(current_user)
      expect(group_card).to have_highlighted_member_count_of(
        PageObjects::Components::GroupCard::MAX_MEMBER_HIGHLIGHT_COUNT,
      )
    end
  end
end
