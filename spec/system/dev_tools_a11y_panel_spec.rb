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
    a11y_panel.test_channel
    expect(a11y_panel).to have_intent_entry
    expect(a11y_panel).to have_spoken_entry

    a11y_panel.clear
    expect(a11y_panel).to have_empty_state

    a11y_panel.pause
    a11y_panel.test_channel
    expect(a11y_panel).to have_empty_state

    a11y_panel.close_dock
    expect(a11y_panel).to have_no_panel
    expect(toolbar).to have_no_active_a11y
  end
end
