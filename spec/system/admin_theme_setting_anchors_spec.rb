# frozen_string_literal: true

describe "Admin theme setting anchors" do
  fab!(:component) { Fabricate(:theme, component: true) }
  fab!(:admin) { Fabricate(:admin, locale: "en") }

  let(:path) { "/admin/customize/components/#{component.id}" }

  before do
    yaml = (1..30).map { |number| "setting_#{number}:\n  type: bool\n  default: false" }.join("\n")
    component.set_field(target: :settings, name: "yaml", value: yaml)
    component.save!
    sign_in(admin)
  end

  it "scrolls to, focuses, and briefly highlights an anchored setting" do
    visit "#{path}#setting-setting_25"

    expect(page).to have_css('[data-setting="setting_25"].--highlighted')
    expect(page).to have_css('[data-setting="setting_25"] .setting-label h3[tabindex="-1"]')
    try_until_success do
      expect(
        page.evaluate_script(
          'document.activeElement === document.querySelector("[data-setting=setting_25] .setting-label h3")',
        ),
      ).to eq(true)
    end

    try_until_success do
      box =
        page.evaluate_script(
          'document.querySelector("[data-setting=setting_25]").getBoundingClientRect().toJSON()',
        )
      expect(box["top"]).to be >= 0
      expect(box["bottom"]).to be <= page.evaluate_script("window.innerHeight")
    end
    expect(page).to have_no_css('[data-setting="setting_25"].--highlighted', wait: 5)
  end

  it "leaves the page as it is for a setting that doesn't exist" do
    visit "#{path}#setting-does_not_exist"
    expect(page).to have_css('[data-setting="setting_1"]')
    expect(page).to have_no_css(".setting.--highlighted")
  end

  it "leaves the page as it is for a malformed setting link" do
    visit "#{path}#setting-%ZZ"
    expect(page).to have_css('[data-setting="setting_1"]')
    expect(page).to have_no_css(".setting.--highlighted")
  end

  it "reveals only the focused setting's link icon" do
    visit path
    page.execute_script('document.querySelector("[data-setting=setting_2] .setting-link").focus()')

    try_until_success do
      expect(
        page.evaluate_script(
          'getComputedStyle(document.querySelector("[data-setting=setting_2] .setting-link")).opacity',
        ),
      ).to eq("1")
      expect(
        page.evaluate_script(
          'getComputedStyle(document.querySelector("[data-setting=setting_3] .setting-link")).opacity',
        ),
      ).to eq("0")
    end
  end
end
