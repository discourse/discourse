# frozen_string_literal: true

RSpec.describe "Illegal content notices" do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "legal_notices", has_messages: true) }
  fab!(:topic)
  fab!(:reported_post) { Fabricate(:post, topic:) }

  let(:explanation) do
    "This listing advertises counterfeit goods as authentic and asks buyers to pay outside the marketplace. The product description and payment instructions appear intended to deceive buyers."
  end

  let(:notice_page) { PageObjects::Pages::DsaNotice.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.title = "Example community"
    SiteSetting.contact_email = "legal@example.invalid"
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_notice_group = group.id.to_s
    SiteSetting.allow_all_users_to_flag_illegal_content = true
    group.add(admin)
  end

  it "accepts a contact notice and makes it available in the group inbox" do
    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reported_post, :flag)
    expect(notice_page).to have_notice_form
    expect(page).to have_current_path(%r{\A/dsa/illegal-content\?content_url=})
    expect(notice_page.form.field("content_url").value).to end_with(reported_post.url)

    notice_page.form.submit
    expect(notice_page.form.field("explanation")).to have_errors("Required")
    expect(notice_page.form.field("name")).to have_errors("Required")
    expect(notice_page.form.field("email")).to have_errors("Required")
    expect(page).to have_no_content("Notice received")

    notice_page.fill_notice(explanation:)
    notice_page.form.field("name").fill_in("Alex Morgan")
    notice_page.form.field("email").fill_in("invalid-address")
    notice_page.form.field("declaration").check
    notice_page.form.submit
    expect(notice_page.form.field("email")).to have_errors("Please enter a valid email address")
    expect(page).to have_no_content("Notice received")

    notice_page.form.field("email").fill_in("alex@example.invalid")
    notice_page.form.submit
    expect(notice_page).to have_confirmation
    expect(notice_page).to have_focused_confirmation
    expect(page).to have_content("We will email you a receipt")
    reference = notice_page.reference

    sign_in(admin)
    notice_page.open_group_notice(user: admin, group:, reference:)
    expect(page).to have_content("alex@example.invalid")
    expect(page).to have_content(explanation)
    expect(page).to have_content("Replies to this PM stay internal.")
    expect(page).to have_no_content("Forum:")
  end

  it "accepts an anonymous notice without retaining contact details" do
    visit("/dsa/illegal-content?content_url=#{CGI.escape(reported_post.full_url)}")
    expect(notice_page).to have_notice_form
    notice_page.fill_notice(explanation:)
    notice_page.form.field("name").fill_in("Discard this name")
    notice_page.form.field("email").fill_in("discard@example.invalid")
    notice_page.form.field("anonymous").check
    expect(notice_page.form).to have_no_field_with_name("name")
    expect(notice_page.form).to have_no_field_with_name("email")
    notice_page.form.field("anonymous").uncheck
    expect(notice_page.form).to have_field_with_name("name")
    expect(notice_page.form).to have_field_with_name("email")
    notice_page.form.field("anonymous").check
    notice_page.form.field("declaration").check
    notice_page.form.submit
    expect(notice_page).to have_confirmation
    expect(notice_page).to have_focused_confirmation
    expect(page).to have_content("Save this reference. You submitted anonymously")
    reference = notice_page.reference

    sign_in(admin)
    notice_page.open_group_notice(user: admin, group:, reference:)
    expect(page).to have_content("Anonymous, no contact details provided")
    expect(page).to have_no_content("Discard this name")
    expect(page).to have_no_content("discard@example.invalid")
  end
end
