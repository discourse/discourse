# frozen_string_literal: true

# Drives styleguide DSelects through the value-based page object API that flag-on specs use,
# built from a plain root selector rather than `by_identifier`.
describe "UiKit | DSelect page object by value" do
  fab!(:admin)

  def select_at(identifier)
    PageObjects::Components::UiKit::DSelect.at("[data-identifier='#{identifier}'][data-trigger]")
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  context "with the start examples" do
    before do
      visit "/styleguide/molecules/select?group=start"
      expect(page).to have_css("[data-identifier='sg-default'][data-trigger]")
    end

    it "selects by value and by name, and reads the selection" do
      default_select = select_at("sg-default")

      default_select.select_value("published")
      expect(default_select).to have_selected_value("published")
      expect(default_select).to have_selected_name("Published")
      expect(default_select.value).to eq("published")

      default_select.select_name("Archived")
      expect(default_select).to have_selected_value("archived")
      expect(default_select).to have_no_selected_name("Published")
    end

    it "checks options in its own panel, opening it when needed" do
      default_select = select_at("sg-default")

      expect(default_select).to have_option_value("draft")
      expect(default_select).to have_no_option_value("missing")
      expect(default_select).to have_option_name("Scheduled")
      expect(default_select).to have_no_option_name("Missing")
      expect(default_select.option_values).to eq(%w[draft published archived scheduled])
    end

    it "closes again" do
      default_select = select_at("sg-default")

      default_select.search("pub")
      expect(page).to have_css("[data-identifier='sg-default'][data-trigger][aria-expanded='true']")

      default_select.close
      expect(page).to have_css(
        "[data-identifier='sg-default'][data-trigger][aria-expanded='false']",
      )
    end

    it "builds a multi-select value and removes a chip" do
      multi = select_at("sg-multi")

      multi.select_value("draft")
      multi.select_value("archived")
      expect(multi).to have_selected_value("draft,archived")
      expect(multi).to have_selected_name("Draft,Archived")

      multi.remove("draft")
      expect(multi).to have_selected_value("archived")
    end

    it "stays scoped to its own select while another one is open" do
      multi = select_at("sg-multi")
      default_select = select_at("sg-default")

      multi.search("arch")
      default_select.select_value("scheduled")

      expect(default_select).to have_selected_value("scheduled")
      expect(multi).to have_selected_value("")
    end

    it "works when built before the page renders" do
      late = select_at("sg-default")
      visit "/styleguide/molecules/select?group=start"

      late.select_value("draft")
      expect(late).to have_selected_value("draft")
    end

    it "works on mobile", mobile: true do
      default_select = select_at("sg-default")

      default_select.search("arch")
      default_select.select_value("archived")

      expect(default_select).to have_selected_value("archived")
    end
  end

  context "with the selection examples" do
    before do
      visit "/styleguide/molecules/select?group=selection"
      expect(page).to have_css("[data-identifier='sg-clearable'][data-trigger]")
    end

    it "clears the selection" do
      clearable = select_at("sg-clearable")
      expect(clearable).to have_selected_value("es")

      clearable.clear
      expect(clearable).to have_selected_value("")
    end

    it "searches through the panel filter of a button select" do
      toggle = select_at("sg-toggle")

      toggle.search("Fran")

      expect(toggle).to have_option_value("fr")
      expect(toggle).to have_no_option_value("de")
    end

    it "sees the options disabled at the selection cap" do
      maximum = select_at("sg-maximum")

      expect(maximum).to have_disabled_option("fr")
    end
  end

  context "with a list longer than the window" do
    before do
      visit "/styleguide/molecules/select?group=limits"
      expect(page).to have_css("[data-identifier='sg-large-list'][data-trigger]")
    end

    it "finds a row that is not mounted yet" do
      large = select_at("sg-large-list")

      large.select_value(60)

      expect(large).to have_selected_value("60")
    end
  end

  context "with a form example" do
    before do
      visit "/styleguide/molecules/select?group=data"
      expect(page).to have_css("[data-test-select-form] .form-kit")
    end

    it "reads and sets DSelect fields through the form page object" do
      form = PageObjects::Components::FormKit.new("[data-test-select-form] .form-kit")

      expect(form.field("locale")).to have_value("es")
      form.field("locale").select("fr")
      expect(form.field("locale")).to have_value("fr")

      expect(form.field("locales")).to have_value("en")
      form.field("locales").select("de")
      expect(form.field("locales")).to have_value("en,de")
    end
  end

  context "with edge cases" do
    it "resolves an inner input lazily before visiting and again after revisiting" do
      select =
        PageObjects::Components::UiKit::DSelect.at(
          "[data-identifier='sg-default'][data-trigger] .d-select__input",
        )

      visit "/styleguide/molecules/select?group=start"
      select.select_value("published")
      expect(select).to have_selected_value("published")

      visit "/styleguide/molecules/select?group=start"
      select.select_value("archived")
      expect(select).to have_selected_value("archived")
    end

    it "opens a static trigger and closes through its controller" do
      visit "/styleguide/molecules/select?group=start"
      select =
        PageObjects::Components::UiKit::DSelect.at("[data-identifier='sg-static'][data-trigger]")

      expect(select).to have_option_value("fr")
      select.close
      expect(select.trigger).to match_css("[aria-expanded='false']")
      select.close
      select.select_value("fr")
      expect(select).to have_selected_value("fr")
    end

    it "replaces searches and closes a button select through its panel filter" do
      visit "/styleguide/molecules/select?group=selection"
      select =
        PageObjects::Components::UiKit::DSelect.at("[data-identifier='sg-toggle'][data-trigger]")

      select.search("Fran")
      expect(select).to have_option_value("fr")
      select.search("Deutsch")
      expect(select).to have_option_value("de")
      expect(select).to have_no_option_value("fr")
      select.close
      expect(select.trigger).to match_css("[aria-expanded='false']")
    end

    it "compares punctuated hooks literally when selecting and removing" do
      visit "/styleguide/molecules/select?group=start"
      select =
        PageObjects::Components::UiKit::DSelect.at("[data-identifier='sg-multi'][data-trigger]")
      literal = "both'\"quotes\\and[brackets],"

      expect(select).to have_option_value("published")
      page.execute_script(
        "arguments[0].setAttribute('data-value', arguments[1]); arguments[0].setAttribute('data-name', arguments[1]);",
        select.options.find { |option| option["data-value"] == "published" },
        literal,
      )
      expect(select).to have_option_value(literal)
      expect(select).to have_option_name(literal)
      select.select_name(literal)
      expect(select).to have_selected_value("published")

      page.execute_script(
        "arguments[0].setAttribute('data-value', arguments[1]);",
        select.chips.first,
        literal,
      )
      select.remove(literal)
      expect(select).to have_selected_value("")

      expect(select).to have_option_value("archived")
      page.execute_script(
        "arguments[0].setAttribute('data-value', arguments[1]);",
        select.options.find { |option| option["data-value"] == "archived" },
        literal,
      )
      select.select_value(literal)
      expect(select).to have_selected_value("archived")
    end

    it "waits for selected hooks and options to lose their previous values" do
      visit "/styleguide/molecules/select?group=start"
      select =
        PageObjects::Components::UiKit::DSelect.at("[data-identifier='sg-default'][data-trigger]")
      select.select_value("published")
      expect(select).to have_selected_value("published")

      %w[value name]
        .zip(%w[published Published])
        .each do |hook, previous|
          page.execute_script(
            "setTimeout(() => arguments[0].setAttribute(arguments[1], ''), 500);",
            select.trigger,
            "data-#{hook}",
          )
          expect(select.public_send("has_no_selected_#{hook}?", previous)).to eq(true)
        end

      expect(select).to have_option_value("draft")
      %w[value name]
        .zip(%w[draft Draft])
        .each do |hook, previous|
          page.execute_script(
            "setTimeout(() => arguments[0].setAttribute(arguments[1], ''), 500);",
            select.options.find { |option| option["data-name"] == "Draft" },
            "data-#{hook}",
          )
          expect(select.public_send("has_no_option_#{hook}?", previous)).to eq(true)
        end
    end

    it "checks and collects every window in order, including rows above the current window" do
      visit "/styleguide/molecules/select?group=limits"
      select =
        PageObjects::Components::UiKit::DSelect.at(
          "[data-identifier='sg-large-list'][data-trigger]",
        )

      expect(select).to have_option_value(60)
      expect(select.option_values).to eq((1..5000).map(&:to_s))
      expect(select).to have_option_value(30)
      select.select_value(75)
      expect(select).to have_selected_value(75)
    end
  end
end
