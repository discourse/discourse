# frozen_string_literal: true

describe "Account activation" do
  fab!(:password) { "myverysecurepassword" }
  fab!(:user) { Fabricate(:user, password: password, active: false) }

  it "can resend activation email and activate account" do
    Jobs.run_immediately!

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".login-button").filter(visible: true).click
    browser_root.locator("#login-account-name").filter(visible: true).fill(user.email)
    browser_root.locator("#login-account-password").filter(visible: true).fill(password)
    browser_root.locator("#login-button").filter(visible: true).click

    not_activated_modal = browser_root.locator(".not-activated-modal").filter(visible: true)

    expect(ActionMailer::Base.deliveries.count).to eq(0)

    not_activated_modal.locator("button.resend").filter(visible: true).click

    wait_for(timeout: 5) { ActionMailer::Base.deliveries.count === 1 }

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to contain_exactly(user.email)

    activate_link = mail.body.to_s[%r{/u/activate-account/\S+}, 0]

    browser_page.goto(activate_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(user.reload.active).to eq(false)

    browser_root.locator(".activate-account-button").filter(visible: true).click

    wait_for(timeout: 5) { user.reload.active }
  end
end
