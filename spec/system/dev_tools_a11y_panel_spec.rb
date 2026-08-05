# frozen_string_literal: true

RSpec.describe "Discourse dev tools a11y panel" do
  let(:toolbar) { PageObjects::Components::DevTools::Toolbar.new }
  let(:a11y_panel) { PageObjects::Components::DevTools::A11yPanel.new }

  it "records intents and deliveries from the toolbar to the timeline" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(toolbar).to have_active_a11y
    expect(a11y_panel).to have_panel
    expect(a11y_panel).to have_empty_state

    # The test channel is the positive control: it pushes a known message
    # through the announcement service, so the tap records the intent and the
    # region observer records the delivery.
    screenshot_marker(label: "a11y-panel-empty", only: :desktop)

    a11y_panel.test_channel
    expect(a11y_panel).to have_intent_entry
    expect(a11y_panel).to have_delivered_entry

    screenshot_marker(label: "a11y-panel-timeline", only: :desktop)

    a11y_panel.clear
    expect(a11y_panel).to have_empty_state

    a11y_panel.pause
    a11y_panel.test_channel
    expect(a11y_panel).to have_empty_state

    a11y_panel.close_dock
    expect(a11y_panel).to have_no_panel
    expect(toolbar).to have_no_active_a11y
  end

  # The regression test for the failure this whole rebuild exists to fix.
  #
  # The previous version of this panel reported a defect on ordinary correct
  # markup — every icon button named by its title, every control inside every
  # dialog — which made the problems filter useless, because a list where
  # everything is flagged ranks nothing.
  #
  # Walking real tab stops on a real page is the only honest way to check that.
  # Fixtures can be made quiet by choosing them carefully; a shipping page
  # cannot.
  it "reports no defects while tabbing through an ordinary page" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(a11y_panel).to have_panel

    25.times { page.send_keys(:tab) }

    # Assert something was actually captured before asserting it was clean.
    # Otherwise a walk that never reached the page, or capture that silently
    # stopped, reads exactly like a page with nothing wrong with it.
    expect(a11y_panel.entry_count).to be > 0
    expect(a11y_panel).to have_no_problems
  end
end
