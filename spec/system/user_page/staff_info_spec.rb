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
      ReviewableFlaggedPost
        .statuses
        .except(:approved)
        .keys
        .map do |status|
          Fabricate(:reviewable_flagged_post, status: status, target_created_by: user)
        end
    end

    context "when there are no approved flagged posts" do
      it "should not display a flagged-posts staff counter" do
        expect(user_page.visit(user).try(:staff_info_flagged_posts_counter)).to be_nil
      end
    end

    context "when there are approved flagged posts" do
      before do
        Fabricate.times(2, :reviewable_flagged_post, status: :approved, target_created_by: user)
      end

      it "should show the right count in the flagged-posts staff counter" do
        user_page.visit(user)
        expect(
          user_page.staff_info_flagged_posts_counter.text.to_i,
        ).to eq ReviewableFlaggedPost.approved.count
      end

      it "should have the right link to user's flagged posts in the flagged-posts staff counter" do
        user_page.visit(user).staff_info_flagged_posts_counter.click
        expect(user_page).to have_reviewable_flagged_posts_path(user)
      end
    end
  end
end
