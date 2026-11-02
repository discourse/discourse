# frozen_string_literal: true

RSpec.describe "Illegal content notices" do
  fab!(:topic)
  fab!(:reported_post) { Fabricate(:post, topic:) }
  fab!(:reporter) { Fabricate(:user, refresh_auto_groups: true) }

  let(:reporting_modal) { PageObjects::Modals::Flag.new }
  let(:explanation) do
    "This listing advertises counterfeit goods as authentic and asks buyers to pay outside the marketplace. The product description and payment instructions appear intended to deceive buyers."
  end

  let(:notice_modal) { PageObjects::Modals::DsaNotice.new }
  let(:notice_page) { PageObjects::Pages::DsaNotice.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.post_menu_hidden_items = ""
    SiteSetting.contact_email = "legal@example.invalid"
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.disable_emails = "no"
    SiteSetting.allow_all_users_to_flag_illegal_content = false
    Jobs.run_immediately!
  end

  it "lets a logged in reporter submit a notice using their account email" do
    reporter.activate
    sign_in(reporter)
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(reporting_modal).to be_open
    reporting_modal.report_illegal_content
    expect(notice_modal).to be_open
    expect(notice_modal).to have_post_url(reported_post)
    expect(notice_modal).to have_no_email_input

    notice_modal.go_back
    expect(reporting_modal).to be_open
    expect(reporting_modal).to have_no_selected_illegal_report
    expect(reporting_modal).to have_no_message_input
    expect(reporting_modal).to have_no_confirmation

    topic_page.visit_topic(topic)
    topic_page.open_flag_topic_modal
    reporting_modal.report_illegal_content
    expect(notice_modal).to be_open
    expect(notice_modal).to have_topic_url(topic)
    expect(notice_modal).to have_no_email_input

    notice_modal.enter_report(name: "Alex Morgan", explanation:)
    notice_modal.accept_declaration
    notice_modal.submit_report
    expect(notice_modal).to have_confirmation
    expect(ActionMailer::Base.deliveries.last.to).to eq([reporter.email])

    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    reporting_modal.choose_type(:off_topic)
    reporting_modal.confirm_flag
    expect(topic_page).to have_post_flagged(post: reported_post, type: :off_topic)

    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(reporting_modal).to be_open
    reporting_modal.report_illegal_content
    expect(notice_modal).to be_open
    expect(notice_modal).to have_post_url(reported_post)
    expect(notice_modal).to have_no_email_input

    notice_modal.go_back
    expect(reporting_modal).to have_no_selected_illegal_report

    notice_page.visit_form
    expect(notice_page).to have_notice_form
    notice_page.submit_report(
      content_url: URI.join(page.current_url, reported_post.url).to_s,
      name: "Alex Morgan",
      explanation:,
    )
    expect(notice_page).to have_confirmation
  end

  it "lets a reporter verify their email and submit an illegal content report" do
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(notice_modal).to be_open
    expect(notice_modal).to have_post_url(reported_post)
    expect(notice_modal).to have_disabled_submit

    notice_modal.enter_email("alex@example.com")
    notice_modal.request_email_code
    expect(notice_modal).to have_verification_code_input
    code = ActionMailer::Base.deliveries.last.text_part.decoded[/\b[0-9]{6}\b/]
    notice_modal.fill_verification_code(code)
    expect(notice_modal).to have_verified_email

    notice_modal.enter_report(name: "Alex Morgan", explanation:)
    expect(notice_modal).to have_declaration(
      "I honestly believe that the facts and claims in this report are true and complete",
    )
    notice_modal.accept_declaration
    notice_modal.submit_report
    expect(notice_modal).to have_confirmation
  end
end
