# frozen_string_literal: true

describe "Viewing user staff info as an admin", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:user_page) { PageObjects::Pages::User.new }

  before { sign_in(admin) }

  context "for warnings" do
    fab!(:topic) { Fabricate(:private_message_topic, user: admin, recipient: user) }
    fab!(:user_warning) { UserWarning.create!(user: user, created_by: admin, topic: topic) }

    it "should display the right link to user's warnings with the right count in text" do
      user_page.visit(user).click_staff_info_warnings_link(user, warnings_count: 1)

      expect(user_page).to have_warning_messages_path(user)
    end
  end

  context "for flagged posts" do
    before do
      %i[disagree ignore delete_and_ignore].each do |review_action|
        PostActionCreator
          .off_topic(admin, Fabricate(:post, user: user))
          .reviewable
          .perform(admin, review_action)
      end
    end

    context "when there are no approved flagged posts" do
      it "should not display a flagged-posts staff counter" do
        user_page.visit(user)
        expect(user_page).to have_no_staff_info_flagged_posts_counter
      end
    end

    context "when there are approved flagged posts" do
      before do
        2.times do
          PostActionCreator
            .off_topic(admin, Fabricate(:post, user: user))
            .reviewable
            .perform(admin, :agree_and_keep)
        end
      end

      it "should display a flagged-posts staff counter with the right count and link to user's flagged posts" do
        user_page.visit(user)

        expect(user_page).to have_staff_info_flagged_posts_count(count: 2)

        user_page.staff_info_flagged_posts_counter.click

        expect(user_page).to have_reviewable_flagged_posts_path(user)
      end
    end
  end
end
