# frozen_string_literal: true

RSpec.describe "Illegal content notices" do
  fab!(:topic)
  fab!(:reported_post) { Fabricate(:post, topic:) }

  let(:explanation) do
    "This listing advertises counterfeit goods as authentic and asks buyers to pay outside the marketplace. The product description and payment instructions appear intended to deceive buyers."
  end

  let(:notice_page) { PageObjects::Pages::DsaNotice.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.contact_email = "legal@example.invalid"
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.disable_emails = "no"
    SiteSetting.allow_all_users_to_flag_illegal_content = true
    Jobs.run_immediately!
  end

  it "lets a reporter verify their email and submit an illegal content report" do
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(notice_page).to have_notice_form
    expect(notice_page.form.field("content_url").value).to end_with(reported_post.url)
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
