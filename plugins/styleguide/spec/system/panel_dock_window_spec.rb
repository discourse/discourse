# frozen_string_literal: true

RSpec.describe "Panel dock window mode" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:styleguide) { PageObjects::Pages::Styleguide.new }

  # The styleguide's tabbed example is the only place window mode is reachable
  # without the developer tools, and it is already the fixture the smoke test
  # drives, so the two stay in step.
  let(:dock) { ".d-panel-dock.--context-styleguide-tabbed-dock" }
  let(:window_button) { "#{dock} .d-panel-dock__dock-button.--window" }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  # The window starts empty and is styled by stylesheets the shell clones into
  # it, so "has the CSS arrived" is the only honest readiness signal.
  def painted?(page, timeout: 20)
    deadline = Time.now + timeout

    while Time.now < deadline
      background =
        page.evaluate_script(
          "getComputedStyle(document.querySelector('.d-panel-dock-window')).backgroundColor",
        )
      return true if background.present? && background != "rgba(0, 0, 0, 0)"
      sleep 0.25
    end

    false
  end

  # Everything here needs a real browser window. The component suite drives an
  # iframe standing in for one, which cannot answer whether a browser actually
  # opens the window, whether the stylesheets the shell clones really apply in
  # it, or whether the icons it mirrors resolve there.
  it "offers moving the panel to a window alongside the three edges" do
    visit "/styleguide/organisms/panel-dock"
    find(".styleguide-panel-dock--tabbed .styleguide-panel-dock__open").click

    expect(page).to have_css("#{dock} .d-panel-dock__dock-button", count: 4)
    expect(page).to have_css("#{window_button}[aria-pressed='false']")
    expect(page).to have_css("#{dock} .d-panel-dock__dock-button.--end[aria-pressed='true']")

    screenshot_marker(label: "panel-dock-windowable-picker")
  end

  it "moves the panel into a real browser window" do
    visit "/styleguide/organisms/panel-dock"
    find(".styleguide-panel-dock--tabbed .styleguide-panel-dock__open").click

    expect(page).to have_css("#{dock}.--dock-end")
    expect(page).to have_css(window_button)

    panel_window = window_opened_by { find(window_button).click }

    expect(page).to have_no_css(dock, wait: 5)
    expect(page).to have_css(".styleguide-panel-dock__status", text: "Placement: window")

    within_window(panel_window) do
      panel = ".d-panel-dock.--window"
      expect(page).to have_css(panel)

      # Waited on the painted result rather than on the shell's own reveal flag:
      # mirroring the page's root attributes clears them before re-adding them,
      # so the flag briefly disappears while the window is still unstyled.
      expect(painted?(page)).to eq(true)

      # Deliberately not photographed by the shared screenshot matrix: that
      # orchestrator re-runs each example once per theme and mode through a
      # nested runner, and cannot hold a second browser window open across
      # those runs. The panel's own window is reviewed from a direct run.
      expect(page).to have_css("#{panel} [role='tab']", count: 3)

      # The panel is the document's only region, and an unnamed one would leave
      # a reader with no way to tell what this window is.
      expect(page).to have_css("#{panel}[role='region'][aria-label]")

      # A cloned stylesheet really applying, rather than merely being present:
      # the shell paints the window's own background from a theme variable.
      background =
        page.evaluate_script(
          "getComputedStyle(document.querySelector('.d-panel-dock-window')).backgroundColor",
        )
      expect(background).not_to be_blank
      expect(background).not_to eq("rgba(0, 0, 0, 0)")

      # An icon resolves against the sprite the shell mirrored. Without that
      # mirroring every `use` reference in the window renders blank.
      expect(page).to have_css("#{panel} svg use")
      resolved = page.evaluate_script(<<~JS)
          (() => {
            const use = document.querySelector('.d-panel-dock.--window svg use');
            if (!use) { return false; }
            const id = (use.getAttribute('href') || '').replace('#', '');
            return id.length > 0 && !!document.getElementById(id);
          })()
        JS
      expect(resolved).to eq(true)
    end
  end

  it "returns the panel when the picker is used inside its window" do
    visit "/styleguide/organisms/panel-dock"
    find(".styleguide-panel-dock--tabbed .styleguide-panel-dock__open").click

    panel_window = window_opened_by { find(window_button).click }
    expect(page).to have_no_css(dock, wait: 5)

    within_window(panel_window) do
      expect(page).to have_css(".d-panel-dock.--window .d-panel-dock__dock-button.--start")

      # Scheduled rather than clicked directly: this click re-docks the panel,
      # which closes the very window the click is being performed in, and the
      # driver cannot finish an action against a target that has gone away.
      page.execute_script(<<~JS)
        setTimeout(
          () => document.querySelector(".d-panel-dock__dock-button.--start").click(),
          0
        );
      JS
    end

    expect(page).to have_css("#{dock}.--dock-start", wait: 5)
    expect(page).to have_css(".styleguide-panel-dock__status", text: "Placement: docked")
  end

  it "brings the panel back when the reader closes its window" do
    visit "/styleguide/organisms/panel-dock"
    find(".styleguide-panel-dock--tabbed .styleguide-panel-dock__open").click

    panel_window = window_opened_by { find(window_button).click }
    expect(page).to have_no_css(dock, wait: 5)

    panel_window.close

    expect(page).to have_css(dock, wait: 5)
    expect(page).to have_css(".styleguide-panel-dock__status", text: "Placement: docked")
  end
end
