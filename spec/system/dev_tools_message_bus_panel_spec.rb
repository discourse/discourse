# frozen_string_literal: true

RSpec.describe "Discourse dev tools MessageBus panel" do
  include ThemeScreenshotMarker

  let(:toolbar) { PageObjects::Components::DevTools::Toolbar.new }
  let(:message_bus_panel) { PageObjects::Components::DevTools::MessageBusPanel.new }

  # Subscribed unconditionally by an instance initializer, so it is present for
  # an anonymous visitor on any page.
  let(:always_subscribed_channel) { "/site/read-only" }

  it "lets the user inspect MessageBus channels and messages from the toolbar" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(toolbar).to have_active_message_bus
    expect(message_bus_panel).to have_panel
    expect(message_bus_panel).to have_status
    expect(message_bus_panel).to have_channel_rows(minimum: 1)
    expect(message_bus_panel).to have_channel_row(always_subscribed_channel)

    message_bus_panel.expand_channel(always_subscribed_channel)
    expect(message_bus_panel).to have_channel_detail
    screenshot_marker(label: "message-bus-panel-detail", only: :desktop)

    message_bus_panel.switch_view("stream")
    expect(message_bus_panel).to have_stream

    # The font tokens are an em ladder that compounds when nested. The channels
    # table and the stream each step down exactly once from the panel root, so
    # the two views must render their body text at the same computed size.
    stream_font_size = message_bus_panel.computed_font_size(".dev-tools-message-bus__stream")

    message_bus_panel.switch_view("channels")
    expect(message_bus_panel.computed_font_size(".dev-tools-message-bus__cell.--channel")).to eq(
      stream_font_size,
    )
    expect(message_bus_panel).to have_channel_row(always_subscribed_channel)

    message_bus_panel.close
    expect(message_bus_panel).to have_no_panel
    expect(toolbar).to have_no_active_message_bus

    toolbar.open_message_bus
    expect(message_bus_panel).to have_panel
    expect(toolbar).to have_active_message_bus
  end

  it "holds the user's scroll position while the panel refreshes itself" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(message_bus_panel).to have_channel_rows(minimum: 1)

    message_bus_panel.scroll_body_to_bottom
    settled_position = message_bus_panel.body_scroll_position

    # The panel re-renders on a 1s tick; two ticks are enough to catch the
    # browser's scroll anchoring yanking the viewport if the fix regresses.
    sleep 2.5

    expect(message_bus_panel.body_scroll_position).to eq(settled_position)
  end

  it "expands a channel from anywhere on its row" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(message_bus_panel).to have_channel_row(always_subscribed_channel)

    message_bus_panel.toggle_channel_via_cell(always_subscribed_channel)
    expect(message_bus_panel).to have_channel_detail
  end

  it "moves a channel to the closed section when its subscriber leaves" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(message_bus_panel).to have_channel_rows(minimum: 1)
    expect(message_bus_panel).to have_no_closed_section

    message_bus_panel.churn_subscription("/spec/closed-demo")

    expect(message_bus_panel).to have_closed_section
    expect(message_bus_panel).to have_closed_channel_row("/spec/closed-demo")
    screenshot_marker(label: "message-bus-panel-closed", only: :desktop)
  end

  it "lets the user close and reopen the active MessageBus tab from the toolbar" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(message_bus_panel).to have_panel
    expect(toolbar).to have_active_message_bus

    toolbar.open_message_bus
    expect(message_bus_panel).to have_no_panel
    expect(toolbar).to have_no_active_message_bus

    toolbar.open_message_bus
    expect(message_bus_panel).to have_panel
    expect(toolbar).to have_active_message_bus
  end

  it "keeps the MessageBus tab open across a page refresh" do
    visit("/latest")
    toolbar.enable
    toolbar.open_message_bus

    expect(message_bus_panel).to have_panel
    expect(toolbar).to have_active_message_bus
    screenshot_marker(label: "message-bus-panel", only: :desktop)

    page.refresh

    expect(toolbar).to have_toolbar
    expect(message_bus_panel).to have_panel
    expect(toolbar).to have_active_message_bus
  end
end
