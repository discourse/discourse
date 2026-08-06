# frozen_string_literal: true

RSpec.describe "Discourse dev tools a11y panel" do
  # Required for a direct run of this file. The screenshot orchestrator also
  # auto-includes it, but relying on that alone breaks running the spec on its own.
  include ThemeScreenshotMarker

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

  # A capture that actually exercises the row grammar, for the visual review.
  #
  # The trace above is one clean merged row, which cannot show the severity rail,
  # the finding line, the ruled blank that stands for silence, the noise floor, or
  # whether the trigger gutter holds its track across rows of different widths.
  it "renders every row shape for review" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(a11y_panel).to have_panel

    # A burst of one event kind, which collapses onto the noise floor.
    #
    # Focused directly rather than tabbed: with the dock open, focus is inside the
    # panel, and the panel excludes its own chrome from the trace it produces — so
    # tabbing here records nothing at all, correctly, and no run ever appears.
    page.execute_script(<<~JS)
      const host = document.createElement("div");
      host.id = "shot-stops";
      for (const name of ["First", "Second", "Third", "Fourth"]) {
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = name;
        host.appendChild(button);
      }
      document.body.appendChild(host);
      for (const button of host.children) {
        button.focus();
      }
    JS

    a11y_panel.test_channel
    expect(a11y_panel).to have_delivered_entry

    # A defect has to be injected: an ordinary Discourse page correctly produces
    # none, which is exactly what the zero-noise gate below asserts. The cursor
    # points nowhere, so this row is both a problem AND silent — it carries the
    # rail, the message line and the ruled blank at once.
    page.execute_script(<<~JS)
      const host = document.createElement("div");
      const composite = document.createElement("div");
      composite.id = "shot-composite";
      composite.setAttribute("role", "listbox");
      composite.setAttribute("aria-label", "Categories");
      composite.setAttribute("tabindex", "0");
      composite.setAttribute("aria-activedescendant", "nowhere");
      host.appendChild(composite);
      document.body.appendChild(host);
      composite.focus();
    JS

    expect(a11y_panel).to have_problem

    screenshot_marker(label: "a11y-panel-grammar", only: :desktop)
  end

  # The other two views. Trace is one of three, so a panel photographed only on
  # Trace has two thirds of its surface unreviewed.
  #
  # Captured at both dock shapes because width is what decides whether these rows
  # have room for a description, its tags, a finding message and a count on one
  # line, and neither view has an alternate narrow layout to fall back on.
  it "renders the Regions and Sweep views for review" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(a11y_panel).to have_panel

    # Every defect here is injected. An ordinary page produces none — that is what
    # the zero-noise gates assert — so a populated capture has to author its own.
    #
    # Regions are created EMPTY and written to further down: a region that already
    # holds text when it is discovered has no delivery and no last-delivery line,
    # which is most of what a Regions row is meant to show.
    page.execute_script(<<~JS)
      const host = document.createElement("div");
      host.id = "shot-a11y-fixtures";

      const region = (id, attributes) => {
        const element = document.createElement("div");
        element.id = id;
        for (const [name, value] of Object.entries(attributes)) {
          element.setAttribute(name, value);
        }
        return element;
      };

      // Two regions whose role and politeness contradict each other, so one rule
      // aggregates a count of two rather than reading as a single stray row.
      host.appendChild(region("shot-queued-alert", { role: "alert", "aria-live": "polite" }));
      host.appendChild(region("shot-barging-status", { role: "status", "aria-live": "assertive" }));

      // The belt-and-braces permutation: NOTED, so it must show in Regions and
      // must NOT show in the sweep.
      host.appendChild(region("shot-redundant-log", { role: "log", "aria-live": "polite" }));

      // A region no reader can reach, which is also the only row carrying the
      // out-of-tree tag.
      const buried = document.createElement("div");
      buried.style.display = "none";
      buried.appendChild(region("shot-buried-region", { "aria-live": "assertive" }));
      host.appendChild(buried);

      // A composite whose cursor points at nothing.
      host.appendChild(
        region("shot-listbox", {
          role: "listbox",
          "aria-label": "Categories",
          tabindex: "0",
          "aria-activedescendant": "nowhere",
        })
      );

      // Checkable items that never say whether they are checked, for a second
      // multi-element rule from a different family.
      const menu = region("shot-menu", { role: "menu", "aria-label": "Filters" });
      for (const name of ["Unread", "Bookmarked"]) {
        const item = document.createElement("div");
        item.setAttribute("role", "menuitemcheckbox");
        item.textContent = name;
        menu.appendChild(item);
      }
      host.appendChild(menu);

      const trigger = document.createElement("button");
      trigger.type = "button";
      trigger.id = "shot-discover";
      trigger.textContent = "Discover";
      host.appendChild(trigger);

      document.querySelector("#main-outlet").appendChild(host);
    JS

    # Region discovery is additive and re-runs per captured event, so the injected
    # regions enter the store only once an event is captured.
    find("#shot-discover").click

    # Now the deliveries: one into an injected region, and one through the service
    # so the regions the product ships carry a count too.
    page.execute_script(<<~JS)
      document.querySelector("#shot-queued-alert").textContent =
        "Your draft could not be saved";
    JS

    a11y_panel.test_channel
    expect(a11y_panel).to have_delivered_entry

    a11y_panel.open_regions
    expect(a11y_panel).to have_broken_region("#shot-queued-alert")

    # Muted deliberately on a row that is NOT the broken one, so the capture shows
    # the muted treatment and the broken rail at the same time instead of one
    # overriding the other.
    a11y_panel.mute_region("#shot-redundant-log")
    expect(a11y_panel).to have_muted_region("#shot-redundant-log")

    screenshot_marker(label: "a11y-panel-regions", only: :desktop)

    # Docking narrow re-renders the panel, so the view has to be re-selected
    # rather than assumed to have survived.
    a11y_panel.dock_to(:start)
    a11y_panel.open_regions
    expect(a11y_panel).to have_broken_region("#shot-queued-alert")

    screenshot_marker(label: "a11y-panel-regions-narrow", only: :desktop)

    a11y_panel.dock_to(:bottom)
    a11y_panel.open_sweep

    expect(a11y_panel).to have_sweep_rule("live.politeness-contradicts-role")
    expect(a11y_panel).to have_sweep_rule("live.not-in-tree")
    expect(a11y_panel).to have_sweep_rule("cursor.dangling")
    expect(a11y_panel).to have_sweep_rule("role.missing-state")

    # Asserted only AFTER the rules above are present, so this cannot pass by the
    # sweep having never run.
    expect(a11y_panel).to have_no_sweep_rule("live.redundant-politeness")

    a11y_panel.expand_sweep_rule("role.missing-state")
    expect(a11y_panel).to have_sweep_element_list

    screenshot_marker(label: "a11y-panel-sweep", only: :desktop)

    a11y_panel.dock_to(:start)
    a11y_panel.open_sweep
    a11y_panel.expand_sweep_rule("role.missing-state")
    expect(a11y_panel).to have_sweep_element_list

    screenshot_marker(label: "a11y-panel-sweep-narrow", only: :desktop)
  end

  # The half of unit 3a that only a real browser can answer.
  #
  # Which Inspector copy is shown is a container query, so it depends on the real
  # cascade and on the panel's own inline size. A rendering test cannot see either:
  # the stylesheet is not reliably loaded there, and a computed-style assertion would
  # pass or fail for reasons unrelated to the markup. The structural half — two
  # copies, no duplicate ids, both reading the same state — is pinned in qunit.
  #
  # These assertions also cover the container DECLARATION, which nothing else can:
  # a container query with no container silently never matches, so neither position
  # would ever apply and both copies would show at once.
  it "shows the Inspector in the position the dock's width calls for" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(a11y_panel).to have_panel

    a11y_panel.test_channel
    expect(a11y_panel).to have_delivered_entry

    # Docked to the bottom the panel is wide, so the detail sits beside the trace.
    a11y_panel.dock_to(:bottom)
    expect(a11y_panel).to have_visible_inspector(:aside)
    expect(a11y_panel).to have_hidden_inspector(:inline)

    # Docked to a side it is narrow, so the detail moves beneath the selected row.
    a11y_panel.dock_to(:start)
    expect(a11y_panel).to have_visible_inspector(:inline)
    expect(a11y_panel).to have_hidden_inspector(:aside)
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
    #
    # Rows of either shape, and specifically evidence of KEY activity: a burst of
    # focus events collapses onto the noise floor, which is not an entry row, so
    # counting entries alone would be satisfied by the unrelated region-watching
    # row while the tab walk went entirely unrecorded.
    expect(a11y_panel.row_count).to be > 0
    expect(a11y_panel).to have_captured_key_activity
    expect(a11y_panel).to have_no_problems
  end

  # One page of tab stops is thin evidence about noise. A topic page is a different
  # composition of the same primitives, and quiet on both is a much stronger claim
  # than quiet on either.
  context "when on a topic page" do
    fab!(:topic) { Fabricate(:post).topic }

    it "reports no defects while tabbing" do
      visit("/t/#{topic.slug}/#{topic.id}")
      toolbar.enable
      toolbar.open_a11y

      expect(a11y_panel).to have_panel

      25.times { page.send_keys(:tab) }

      expect(a11y_panel.row_count).to be > 0
      expect(a11y_panel).to have_captured_key_activity
      expect(a11y_panel).to have_no_problems
    end
  end

  # The composer is the densest interactive surface in the product and the one most
  # likely to produce a false positive, so it is the hardest place for the catalogue
  # to stay quiet.
  context "in the composer" do
    fab!(:composer_user, :admin)

    before { sign_in(composer_user) }

    it "reports no defects while tabbing" do
      # Dev tools are enabled BEFORE the composer is opened. Enabling them re-renders
      # enough to close it, which cost two runs here and one on the login flow.
      visit("/latest")
      toolbar.enable
      toolbar.open_a11y
      expect(a11y_panel).to have_panel

      visit("/new-topic")
      expect(page).to have_css(".d-editor-input")

      # Focus has to start in the COMPOSER. Opening the dock leaves it inside the
      # panel, whose own chrome is excluded from the trace, so tabbing from there
      # records nothing at all — correctly, and indistinguishably from a clean walk.
      find(".d-editor-input").click

      15.times { page.send_keys(:tab) }

      expect(a11y_panel.row_count).to be > 0

      # NOT asserted as silent, because the composer is not.
      #
      # The walk finds one real defect: a float-kit menu trigger rendered as a
      # `<button>` with no accessible name, so a reader announces only "button". The
      # panel is right, and a true positive must not be dressed up as noise.
      #
      # Asserted as "nothing UNEXPECTED" rather than as an exact set. How far fifteen
      # tab stops reach depends on page state that varies between runs — the
      # onboarding banner, what the sidebar happens to hold — so whether the walk
      # reaches that trigger at all is not stable. Subtracting the known finding is,
      # and it still fails on any problem that is not this one.
      expect(a11y_panel.problem_texts - [I18n.t("js.dev_tools.a11y.findings.focus.no_name")]).to eq(
        [],
      )
    end
  end

  # THE POSITIVE CONTROL, and the other half of the argument.
  #
  # Every gate above proves the catalogue stays QUIET on correct markup. On its own
  # that is satisfiable by a catalogue that detects nothing at all — the failure in the
  # opposite direction from the one this rebuild is correcting. So one gate has to
  # FIRE, end to end: engine, sweep, aggregation and view.
  #
  # The defect is INJECTED rather than borrowed from the product, deliberately.
  # `code-login-form.gjs` really does render `role="alert"` together with
  # `aria-live="polite"` at four call sites, and this gate was written against it —
  # but a test that needs a product bug to survive punishes whoever fixes the bug,
  # with a failure that says nothing about why. That coupling runs the wrong way.
  #
  # What is worth keeping from the real-markup version is recorded rather than
  # depended upon: the rule fires on shipping code, verified by hand, and fixing that
  # form is a separate change this suite must not obstruct.
  #
  # Found by SWEEP rather than by tabbing, because a region verdict is a property of
  # the page and not something that happened.
  it "reports a queued alert that a page really contains" do
    visit("/latest")
    toolbar.enable
    toolbar.open_a11y

    expect(a11y_panel).to have_panel

    page.execute_script(<<~JS)
      const region = document.createElement("div");
      region.id = "queued-alert";
      region.setAttribute("role", "alert");
      region.setAttribute("aria-live", "polite");
      document.querySelector("#main-outlet").appendChild(region);
    JS

    a11y_panel.open_sweep

    expect(a11y_panel).to have_sweep_rule("live.politeness-contradicts-role")
  end
end
