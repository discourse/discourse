# frozen_string_literal: true

describe "Login", type: :system do
  let(:login_modal) { PageObjects::Modals::Login.new }
  fab!(:alex) do
    Fabricate(:user, username: "alex", password: "supersecurepassword", approved: true)
  end

  context "with username and password" do
    it "can login and activate account" do
      Jobs.run_immediately!

      login_modal.open
      login_modal.fill_username("alex")
      login_modal.fill_password("supersecurepassword")
      login_modal.confirm_login

      find(".activation-controls button.resend").click

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(alex.email)
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}, 0]

      visit activation_link
      find("#activate-account-button").click

      visit "/"
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login" do
      # TODO: add test
    end

    it "can reset password" do
      # TODO: add test
    end
  end

  context "with magic link" do
    it "can login" do
      # TODO: add test
    end
  end

  context "with passkey" do
    it "can login" do
      # TODO: move existing tests here (?)
    end
  end

  context "when site is login required" do
    it "can login" do
      # TODO: add test
    end
  end
end
