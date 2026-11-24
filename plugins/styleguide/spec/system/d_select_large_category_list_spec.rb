# frozen_string_literal: true

# Real-browser coverage for `DSelectCategory` over 10,000 preloaded categories, through the
# styleguide's opt-in large category example. Rendering tests mount every row a source
# returns, so only a real browser shows what a reader of a large site gets.
describe "UiKit | DSelectCategory with 10,000 categories" do
  fab!(:admin)

  let(:picker) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-large-category-list") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=limits"
    click_button(I18n.t("js.styleguide.sections.select.large_category_list_load"))
    expect(page).to have_css("[data-identifier='sg-large-category-list'][data-trigger]")
  end

  def timed(label)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    puts "#{label}: #{elapsed}ms" if ENV["DSELECT_TIMINGS"]
  end

  it "opens, searches and picks among them" do
    timed("open") do
      picker.open
      expect(page).to have_css(picker.option_selector)
    end

    timed("search") do
      picker.search("sample category 42-3-7")
      expect(picker).to have_option_value(9_000_000 + 1 + (42 * 100) + 1 + (3 * 11) + 1 + 7)
    end

    name = I18n.t("js.styleguide.sections.select.large_category_list_sample", path: "42-3-7")
    timed("pick") do
      picker.select_name(name)
      expect(picker).to have_selected_name(name)
    end
  end
end
