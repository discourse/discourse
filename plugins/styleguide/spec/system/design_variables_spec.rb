# frozen_string_literal: true

RSpec.describe "Styleguide design variables" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  it "lists core's design variables with what theme styles may change, and filters them" do
    visit "/styleguide/atoms/design-variables"

    radius = find(".styleguide-design-variables__row[data-variable='--d-border-radius-large']")
    expect(radius).to have_text("length")
    expect(radius).to have_text("0px to 32px")

    find(".styleguide-design-variables__filter input").fill_in(with: "--d-tooltip-")
    expect(page).to have_css(".styleguide-design-variables__row.--not-editable")
    expect(page).to have_css(
      ".styleguide-design-variables__row[data-variable='--d-tooltip-border']",
    )
    expect(page).to have_no_css(
      ".styleguide-design-variables__row[data-variable='--d-border-radius-large']",
    )

    find(".styleguide-design-variables__palette summary").click
    expect(page).to have_css(".styleguide-design-variables__palette code", text: "--primary")
  end
end
