# frozen_string_literal: true

describe "Impersonation" do
  fab!(:admin)
  fab!(:user)

  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  it "allows you to start and stop impersonating with the click of a button" do
    browser_page
      .goto("/admin/users/#{user.id}/#{user.username}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".btn-impersonate").filter(visible: true).click

    expect(browser_page).to have_url("/")
    expect(browser_root.locator(".impersonation-notice").filter(visible: true)).to contain_text(
      [browser_text_pattern(I18n.t("js.impersonation.notice", username: user.username))],
      useInnerText: true,
    )

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".impersonation-notice .btn-danger").filter(visible: true).click

    expect(browser_page).to have_url("/")
    expect(browser_root.locator(".impersonation-notice").filter(visible: true)).to have_count(0)
  end

  it "shows a helpful error when the user is not found" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(Discourse::NotFound)

    browser_page
      .goto("/admin/users/#{user.id}/#{user.username}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".btn-impersonate").filter(visible: true).click

    expect(dialog).to be_open
    expect(dialog).to have_displayed_content(I18n.t("admin_js.admin.impersonate.not_found"))
  end

  it "shows a helpful error when impersonation of that user is not allowed" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(Discourse::InvalidAccess)

    browser_page
      .goto("/admin/users/#{user.id}/#{user.username}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator(".btn-impersonate").filter(visible: true).click

    expect(dialog).to be_open
    expect(dialog).to have_displayed_content(I18n.t("admin_js.admin.impersonate.invalid"))
  end

  it "shows a helpful error when there's an unexpected server error" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(StandardError)

    browser_page
      .goto("/admin/users/#{user.id}/#{user.username}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    # Suppress the expected error from the intentionally raised StandardError
    silence_stdout do
      browser_root.locator(".btn-impersonate").filter(visible: true).click

      expect(dialog).to be_open
      expect(dialog).to have_displayed_content(I18n.t("admin_js.admin.impersonate.error"))
    end
  end
end
