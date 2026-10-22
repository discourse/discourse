# frozen_string_literal: true

# A panel holding two DSelectLists, a checkbox and a button, driven with a real keyboard. Tab
# order across the lists, their held-item strips and the controls between them is decided by the
# browser, so a component test cannot show it.
describe "UiKit | DSelectList in a panel" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:panel) { "[data-identifier='sg-select-list'][data-content]" }
  let(:include_list) do
    PageObjects::Components::UiKit::DSelect.at("#{panel} .select-examples__tag-list.--include")
  end
  let(:exclude_list) do
    PageObjects::Components::UiKit::DSelect.at("#{panel} .select-examples__tag-list.--exclude")
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  def open_panel
    visit "/styleguide/molecules/select?group=selection"
    find("[data-identifier='sg-select-list'][data-trigger]").click
    expect(page).to have_css("#{panel} .d-select.--list")
  end

  def focused?(selector)
    page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
  end

  # The suggestions already list every tag, so wait for the query's own answer to take the cursor
  # and its last request to settle before pressing Enter; Enter during a search in flight is
  # deliberately refused.
  def expect_active(list, name)
    scope = "#{panel} .select-examples__tag-list.--#{list}"
    expect(page).to have_no_css("#{scope} input[role='combobox'][aria-busy='true']")
    expect(page).to have_css("#{scope} [role='option'].--active", text: name)
  end

  def toggle_exclude
    find(
      "#{panel} .form-kit__control-checkbox-label",
      text: I18n.t("js.styleguide.sections.select.list_exclude"),
    ).click
  end

  def tab
    page.send_keys(:tab)
  end

  it "tabs through both lists and the controls between them, and selects in each" do
    open_panel

    expect(include_list).to have_selected_name("design-system")

    include_list.input.click
    tab
    expect(focused?("#{panel} .select-examples__tag-list.--include .d-select__strip-remove")).to eq(
      true,
    )

    tab
    expect(focused?("#{panel} input[type='checkbox']")).to eq(true)
    page.send_keys(:space)
    expect(page).to have_css("#{panel} .select-examples__tag-list.--exclude")

    tab
    expect(focused?("#{panel} .select-examples__tag-list.--exclude input[role='combobox']")).to eq(
      true,
    )

    page.send_keys("theming")
    expect_active("exclude", "theming")
    page.send_keys(:enter)
    expect(exclude_list).to have_selected_name("theming")

    include_list.input.click
    page.send_keys("access")
    expect_active("include", "accessibility")
    page.send_keys(:enter)
    expect(include_list).to have_selected_names("design-system", "accessibility")
    expect(exclude_list).to have_selected_name("theming")
  end

  it "drops the excluded tags when exclusion is turned off, and clears everything" do
    open_panel

    toggle_exclude
    exclude_list.input.click
    page.send_keys("theming")
    expect_active("exclude", "theming")
    page.send_keys(:enter)
    expect(exclude_list).to have_selected_name("theming")

    toggle_exclude
    expect(page).to have_no_css("#{panel} .select-examples__tag-list.--exclude")

    toggle_exclude
    expect(exclude_list).to have_no_selected_name("theming")

    find("#{panel} .btn-flat", text: I18n.t("js.styleguide.sections.select.list_clear")).click
    expect(include_list).to have_no_selected_name("design-system")
    expect(page).to have_no_css("#{panel} .select-examples__tag-list.--exclude")
    expect(page).to have_no_css("#{panel} input[type='checkbox']:checked", visible: :all)
  end

  it "shows both lists with held tags" do
    open_panel
    toggle_exclude
    exclude_list.input.click
    page.send_keys("theming")
    expect_active("exclude", "theming")
    page.send_keys(:enter)
    expect(exclude_list).to have_selected_name("theming")
    include_list.input.click

    screenshot_marker(label: "dselect-list-panel")
  end
end
