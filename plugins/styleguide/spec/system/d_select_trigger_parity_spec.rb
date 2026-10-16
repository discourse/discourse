# frozen_string_literal: true

# The hero puts a single-select, a multi-select and a static select in one row, which is the
# arrangement that shows whether they read as one system. Both assertions below are equalities
# rather than absolute figures, so they survive a change to the type scale or the field padding
# and only fail when the variants stop agreeing with each other.
describe "UiKit | DSelect trigger parity" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    SiteSetting.navigation_menu = "sidebar"
    sign_in(admin)
    visit "/styleguide/molecules/select?group=start"
    expect(page).to have_css("[data-identifier='sg-hero-category'][data-trigger]")
  end

  def trigger_height(identifier)
    page.evaluate_script(
      "document.querySelector(\"[data-identifier='#{identifier}'][data-trigger]\")" \
        ".getBoundingClientRect().height",
    ).to_f
  end

  # A chip carried vertical padding the single-select had no equivalent of, and because no
  # trigger variant declares a height the difference passed straight through to the field.
  it "gives every trigger variant the same height in a row of fields" do
    heights =
      %w[sg-hero-category sg-hero-tags sg-hero-notifications].map { |id| trigger_height(id) }

    expect(heights.max - heights.min).to be < 1.0,
    "trigger heights differ by #{(heights.max - heights.min).round(2)}px: #{heights.inspect}"
  end

  # A chip and the query input beside it are the same kind of thing, so they read at the same
  # size; and a category badge brings a smaller size of its own that must not survive into a
  # trigger, where it would undercut every sibling field.
  it "renders chips, badges and trigger text at one size" do
    trigger_font =
      page.evaluate_script(
        "getComputedStyle(document.querySelector(" \
          "\"[data-identifier='sg-hero-notifications'][data-trigger]\")).fontSize",
      )
    chip_font =
      page.evaluate_script("getComputedStyle(document.querySelector('.d-combobox__chip')).fontSize")
    badge_font =
      page.evaluate_script(
        "getComputedStyle(document.querySelector('.badge-category__wrapper')).fontSize",
      )

    expect(chip_font).to eq(trigger_font)
    expect(badge_font).to eq(trigger_font)
  end
end
