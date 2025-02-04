# frozen_string_literal: true

describe "Account activation", type: :system do
  fab!(:password) { "myverysecurepassword" }
  fab!(:user) { Fabricate(:user, password: password, active: false) }

  it "can resend activation email and activate account" do
    Jobs.run_immediately!

    visit "/"
    find(".login-button").click
    find("#login-account-name").fill_in with: user.email
    find("#login-account-password").fill_in with: password
    find("#login-button").click

    not_activated_modal = find(".not-activated-modal")

    expect(ActionMailer::Base.deliveries.count).to eq(0)

    not_activated_modal.find("button.resend").click

    wait_for(timeout: 5) { ActionMailer::Base.deliveries.count === 1 }

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(user.email)

    activate_link = mail.body.to_s[%r{/u/activate-account/\S+}, 0]

    visit activate_link

    expect(user.reload.active).to eq(false)

    find(".activate-account-button").click

    wait_for(timeout: 5) { user.reload.active }
  end
end
