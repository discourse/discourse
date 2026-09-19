# frozen_string_literal: true

describe "Impersonation" do
  fab!(:admin)
  fab!(:user)

  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  it "allows you to start and stop impersonating with the click of a button" do
    visit("/admin/users/#{user.id}/#{user.username}")

    page.find(".btn-impersonate").click

    expect(page).to have_current_path("/")
    expect(page).to have_css(
      ".impersonation-notice",
      text: I18n.t("js.impersonation.notice", username: user.username),
    )

    visit("/latest")

    page.find(".impersonation-notice .btn-danger").click

    expect(page).to have_current_path("/")
    expect(page).to have_no_css(".impersonation-notice")
  end

  it "shows a helpful error when the user is not found" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(Discourse::NotFound)

    visit("/admin/users/#{user.id}/#{user.username}")

    page.find(".btn-impersonate").click

    expect(dialog).to be_open
    expect(dialog).to have_content(I18n.t("admin_js.admin.impersonate.not_found"))
  end

  it "shows a helpful error when impersonation of that user is not allowed" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(Discourse::InvalidAccess)

    visit("/admin/users/#{user.id}/#{user.username}")

    page.find(".btn-impersonate").click

    expect(dialog).to be_open
    expect(dialog).to have_content(I18n.t("admin_js.admin.impersonate.invalid"))
  end

  it "shows a helpful error when there's an unexpected server error" do
    Admin::ImpersonateController.any_instance.stubs(:create).raises(StandardError)

    visit("/admin/users/#{user.id}/#{user.username}")

    # Suppress the expected error from the intentionally raised StandardError
    silence_stdout do
      page.find(".btn-impersonate").click

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("admin_js.admin.impersonate.error"))
    end
  end
end
