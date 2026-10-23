# frozen_string_literal: true

RSpec.describe "Illegal content notices" do
  fab!(:topic)
  fab!(:reported_post) { Fabricate(:post, topic:) }
  fab!(:reporter) { Fabricate(:user, refresh_auto_groups: true) }

  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:explanation) do
    "This listing advertises counterfeit goods as authentic and asks buyers to pay outside the marketplace. The product description and payment instructions appear intended to deceive buyers."
  end

  let(:notice_page) { PageObjects::Pages::DsaNotice.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.post_menu_hidden_items = ""
    SiteSetting.contact_email = "legal@example.invalid"
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.disable_emails = "no"
    SiteSetting.allow_all_users_to_flag_illegal_content = true
    Jobs.run_immediately!
  end

  it "lets a logged in reporter open the notice form from post and topic flagging" do
    sign_in(reporter)
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(flag_modal).to be_open
    expect(flag_modal).to have_no_illegal_flag_choice
    flag_modal.report_illegal_content
    expect(flag_modal).to be_closed
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to eq(
      URI.join(page.current_url, reported_post.url).to_s,
    )

    topic_page.visit_topic(topic)
    topic_page.open_flag_topic_modal
    expect(flag_modal).to have_no_illegal_flag_choice
    flag_modal.report_illegal_content
    expect(flag_modal).to be_closed
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to eq(
      URI.join(page.current_url, topic.relative_url).to_s,
    )

    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    flag_modal.choose_type(:off_topic)
    flag_modal.confirm_flag
    expect(page).to have_content(I18n.t("js.post.actions.by_you.off_topic"))
  end

  it "lets a mobile reporter follow a long translated report link", mobile: true do
    label = "Report illegal content with an explanation " + "Example" * 20
    TranslationOverride.upsert!("en", "js.dsa_notice.title", label)
    sign_in(reporter)
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)

    expect(flag_modal).to have_wrapped_illegal_content_link(label)
    flag_modal.report_illegal_content
    expect(notice_page).to have_notice_form
  end

  it "lets a silenced reporter open the notice form directly" do
    UserSilencer.silence(reporter)
    sign_in(reporter)
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)

    expect(flag_modal).to be_closed
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to eq(
      URI.join(page.current_url, reported_post.url).to_s,
    )
  end

  it "lets a reporter verify their email and submit an illegal content report" do
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to eq(
      URI.join(page.current_url, reported_post.url).to_s,
    )
    expect(page).to have_button("Submit report", disabled: true)

    notice_page.form.field("email").fill_in("alex@example.com")
    notice_page.request_email_code
    expect(notice_page.form).to have_field_with_name("verification_code")
    code = ActionMailer::Base.deliveries.last.text_part.decoded[/\b[0-9]{6}\b/]
    notice_page.fill_verification_code(code)
    expect(notice_page).to have_verified_email
    expect(page).to have_field("Email address", disabled: true)

    notice_page.form.field("name").fill_in("Alex Morgan")
    notice_page.form.field("explanation").fill_in(explanation)
    notice_page.form.field("declaration").check
    notice_page.form.submit
    expect(notice_page).to have_confirmation
  end
end
