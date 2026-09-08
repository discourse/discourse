# frozen_string_literal: true

RSpec.describe "Changing the email of a deactivated account" do
  let(:account_activation_page) { PageObjects::Pages::AccountActivation.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:replacement_email) { "former-member@example.net" }

  fab!(:password) { "correct horse battery staple" }
  fab!(:admin)
  fab!(:user) do
    Fabricate(:user, active: true, approved: true, password: password, email: "member@employer.example")
  end
  fab!(:post) { Fabricate(:post, raw: "Information for current members") }

  before do
    SiteSetting.login_required = true
    SiteSetting.must_approve_users = true
    Jobs.run_immediately!
    ActionMailer::Base.deliveries.clear
    user.deactivate(admin)
  end

  it "requires staff approval after the user activates a replacement email" do
    topic_page.visit_topic(post.topic)
    expect(login_page).to be_open

    login_page.fill(username: user.username, password: password).click_login
    expect(account_activation_page).to be_editable

    account_activation_page.change_email(replacement_email)

    wait_for(timeout: 5) { ActionMailer::Base.deliveries.present? }
    activation_email = ActionMailer::Base.deliveries.last
    expect(activation_email.to).to contain_exactly(replacement_email)

    activation_link = activation_email.body.to_s[%r{/u/activate-account/\S+}, 0]
    account_activation_page.activate_from(activation_link)

    expect(account_activation_page).to be_approval_required

    topic_page.visit_topic(post.topic)
    expect(login_page).to be_open
  end
end
