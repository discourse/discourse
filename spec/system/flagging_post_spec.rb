# frozen_string_literal: true

describe "Flagging post" do
  fab!(:current_user, :admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:post_to_flag) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:silence_user_modal) { PageObjects::Modals::PenalizeUser.new("silence") }
  let(:review_page) { PageObjects::Pages::Review.new }

  describe "Using Take Action" do
    before { sign_in(current_user) }

    it "can select the default action to hide the post, agree with other flags, and reach the flag threshold" do
      other_flag = Fabricate(:flag_post_action, post: post_to_flag, user: Fabricate(:moderator))
      other_flag_reviewable =
        Fabricate(:reviewable_flagged_post, target: post_to_flag, created_by: other_flag.user)
      expect(other_flag.reload.agreed_at).to be_nil
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.click_post_action_button(post_to_flag, :flag)
      flag_modal.choose_type(:off_topic)
      flag_modal.take_action(:agree_and_hide)

      expect(
        topic_page.post_by_number(post_to_flag).ancestor(".topic-post.post-hidden"),
      ).to be_present

      visit "/review/#{other_flag_reviewable.id}"

      expect(review_page).to have_reviewable_with_approved_status(other_flag_reviewable)
    end

    it "can choose to immediately silence the user" do
      expect(Reviewable.count).to eq(0)

      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.click_post_action_button(post_to_flag, :flag)
      flag_modal.choose_type(:off_topic)
      flag_modal.take_action(:agree_and_silence)

      silence_user_modal.fill_in_silence_reason("spamming")
      silence_user_modal.set_future_date("tomorrow")
      silence_user_modal.perform

      expect(silence_user_modal).to be_closed

      expect(
        topic_page.post_by_number(post_to_flag).ancestor(".topic-post.post-hidden"),
      ).to be_present

      visit "/review/#{Reviewable.sole.id}"

      expect(review_page).to have_reviewable_with_approved_status(Reviewable.sole)
    end
  end

  describe "As send a message to user" do
    before do
      SiteSetting.allow_user_locale = true
      current_user.update!(locale: "en_GB")
      sign_in(current_user)
    end

    it do
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.click_post_action_button(post_to_flag, :flag)
      flag_modal.choose_type(:notify_user)

      flag_modal.fill_message("This looks totally illegal to me.")

      flag_modal.confirm_flag

      expect(page).to have_content(I18n.t("js.post.actions.by_you.notify_user"))
    end
  end

  context "when tl0" do
    fab!(:tl0_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
    before { sign_in(tl0_user) }

    it "does not allow to mark posts as illegal" do
      topic_page.visit_topic(topic)
      expect(topic_page).to have_no_flag_button
    end
  end

  context "when anonymous" do
    let(:anonymous_flag_modal) { PageObjects::Modals::AnonymousFlag.new }

    it "does not allow to mark posts as illegal" do
      topic_page.visit_topic(topic)
      expect(topic_page).to have_no_post_more_actions(post_to_flag)
    end

    it "opens the configured reporting form without creating a flag" do
      SiteSetting.illegal_content_reporting_url = "https://example.com/report"
      topic_page.visit_topic(topic, post_number: post_to_flag.post_number)
      topic_page.find_post_action_button(post_to_flag, :flag).click

      expect(anonymous_flag_modal.body).to have_link(
        "this form",
        href: SiteSetting.illegal_content_reporting_url,
      )
      expect(PostAction.where(post: post_to_flag)).to be_empty
    end
  end
end
