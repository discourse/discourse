# frozen_string_literal: true

# Diagnostic first, regression guard second. The reported symptom is that the option list does
# not line up with the dropdown around it, but the overlay is a stack of four boxes — trigger,
# menu content, panel, scroll viewport — and any adjacent pair could be the one that diverges.
# Measuring all of them says which, rather than guessing at a fix for the wrong pair.
describe "UiKit | DSelect overlay widths" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    SiteSetting.navigation_menu = "sidebar"
    sign_in(admin)
  end

  def width_of(selector)
    page.evaluate_script(<<~JS).to_f
      (function () {
        const el = document.querySelector("#{selector}");
        return el ? el.getBoundingClientRect().width : -1;
      })()
    JS
  end

  # A grouped people list with custom rows: the arrangement in the report, and the one most
  # likely to introduce an intrinsic width of its own through row content.
  it "keeps the trigger, panel and option list on one width" do
    visit "/styleguide/molecules/select?group=content"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-grouped")
    combobox.open
    expect(page).to have_css(combobox.option_selector, wait: 10)

    trigger = width_of("[data-identifier='sg-grouped'][data-trigger]")
    content = width_of("[data-identifier='sg-grouped'][data-content]")
    panel = width_of("#{combobox.in_panel(".d-combobox__panel")}")
    viewport = width_of("#{combobox.in_panel(".d-virtual-list")}")
    listbox = width_of("#{combobox.in_panel("[role=listbox]")}")
    option = width_of("#{combobox.option_selector}")

    measured = {
      trigger: trigger,
      content: content,
      panel: panel,
      viewport: viewport,
      listbox: listbox,
      option: option,
    }

    # Reported together so a failure names every box at once; chasing one pair at a time hides
    # which link in the chain actually breaks.
    expect(measured.values).to all(be > 0), "a box did not render: #{measured.inspect}"

    # The one that was broken: the overlay carries both an inline matched width and an inline
    # max-width, and the cap won, so a field wider than it opened a narrower dropdown.
    expect((content - trigger).abs).to be < 1.0, "content vs trigger: #{measured.inspect}"

    # Inside the overlay every box already agreed. Kept as a guard, with the two allowances that
    # are real layout rather than drift: the panel sits inside the content box's border, and the
    # scroll viewport exceeds the listbox by the scrollbar gutter.
    expect((content - panel).abs).to be < 4.0, "panel vs content: #{measured.inspect}"
    expect((viewport - panel).abs).to be < 1.0, "viewport vs panel: #{measured.inspect}"
    expect(viewport - listbox).to be < 20.0, "listbox vs viewport: #{measured.inspect}"
    expect((option - listbox).abs).to be < 1.0, "option vs listbox: #{measured.inspect}"
  end
end
