# frozen_string_literal: true

RSpec.describe "Finish Installation", type: :system do
  before do
    SiteSetting.has_login_hint = true
    GlobalSetting.stubs(:developer_emails).returns("dev@example.com")
  end

  it "renders first screen" do
    visit "/finish-installation"

    find(".finish-installation__register").click

    expect(page).to have_css(".wizard-container__combobox") # email field
    expect(page).to have_css(".input-area")
    expect(page).to have_css(".wizard-container__button") # submit button

    # TODO: add more steps here to ensure full flow works
  end
end
