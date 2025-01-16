# frozen_string_literal: true

describe "Flagging post", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:post_to_flag) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }

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

      expect(page).to have_content(I18n.t("js.review.statuses.approved_flag.title"))
      expect(page).to have_css(".reviewable-meta-data .status .approved")
    end
  end

  describe "As Illegal" do
    before { sign_in(current_user) }

    it do
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.click_post_action_button(post_to_flag, :flag)
      flag_modal.choose_type(:illegal)

      expect(flag_modal).to have_css(".flag-confirmation")

      flag_modal.fill_message("This looks totally illegal to me.")
      flag_modal.check_confirmation

      flag_modal.confirm_flag

      expect(page).to have_content(I18n.t("js.post.actions.by_you.illegal"))
    end
  end

  context "when tl0" do
    fab!(:tl0_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
    before { sign_in(tl0_user) }

    it "does not allow to mark posts as illegal" do
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      expect(topic_page).to have_no_flag_button
    end

    it "allows to mark posts as illegal when allow_tl0_and_anonymous_users_to_flag_illegal_content setting is enabled" do
      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      SiteSetting.allow_tl0_and_anonymous_users_to_flag_illegal_content = true
      topic_page.visit_topic(topic).open_flag_topic_modal
      expect(flag_modal).to have_choices(I18n.t("js.flagging.formatted_name.illegal"))
    end
  end

  context "when anonymous" do
    let(:anonymous_flag_modal) { PageObjects::Modals::AnonymousFlag.new }

    it "does not allow to mark posts as illegal" do
      topic_page.visit_topic(topic)
      expect(topic_page).to have_no_post_more_actions(post_to_flag)
    end

    it "allows to mark posts as illegal when allow_tl0_and_anonymous_users_to_flag_illegal_content setting is enabled" do
      SiteSetting.contact_email = "contact@example.com"
      SiteSetting.allow_tl0_and_anonymous_users_to_flag_illegal_content = true

      topic_page.visit_topic(topic, post_number: post_to_flag.post_number)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.find_post_action_button(post_to_flag, :flag).click

      expect(anonymous_flag_modal.body).to have_content(
        ActionView::Base.full_sanitizer.sanitize(
          I18n.t(
            "js.anonymous_flagging.description",
            { email: "contact@example.com", topic_title: topic.title, url: current_url },
          ),
        ),
      )

      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_to_flag)
      topic_page.find_post_action_button(post_to_flag, :flag).click

      expect(anonymous_flag_modal.body).to have_content(
        ActionView::Base.full_sanitizer.sanitize(
          I18n.t(
            "js.anonymous_flagging.description",
            { email: "illegal@example.com", topic_title: topic.title, url: current_url },
          ),
        ),
      )
    end
  end
end
