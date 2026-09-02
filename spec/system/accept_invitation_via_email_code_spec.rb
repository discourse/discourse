# frozen_string_literal: true

RSpec.describe "Accept invitation via email code" do
  fab!(:invite) { Fabricate(:invite, email: "invited@example.com") }
  fab!(:topic, :topic_with_op)

  let(:invite_form) { PageObjects::Pages::InviteForm.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    invite.update!(topics: [topic])
    Jobs.run_immediately!
  end

  it "lets an invited person verify their email without choosing a password" do
    invite_form.open(invite.invite_key)

    expect(invite_form).to have_email_code_request
    expect(invite_form).to have_no_password_field

    invite_form.request_email_code
    expect(invite_form).to have_email_code_entry

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(invite.email)

    invite_form.enter_email_code(mail.subject[/\d{6}/])
    expect(invite_form).to have_account_ready_step

    invite_form.choose_code_signup_username("invited-person")
    invite_form.continue_code_signup

    expect(page).to have_current_path(topic.relative_url)
    expect(topic_page).to have_post_number(1)
    expect(page).to have_css(".header-dropdown-toggle.current-user")
  end
end
