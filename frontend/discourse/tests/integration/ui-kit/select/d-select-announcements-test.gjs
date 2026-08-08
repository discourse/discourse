import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import {
  settledAnnouncements,
  trackAnnouncements,
} from "discourse/tests/helpers/aria-patterns/announcements";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

// Announcement contracts: what the live regions say, how often, and how politely.
//
// These read the regions themselves rather than spying on the `a11y` service. A spy proves a call
// was made; only the region proves a message landed somewhere a reader would reach it, in an order
// and at a cadence a reader could follow. The distinction is what the "two announcements racing for
// one voice" defect turned on — both calls happened, and the user still heard only one.

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

class Host extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <A11yLiveRegions />
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @placeholder="Pick one"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect announcements",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      // Otherwise a message clears mid-test and the log races the auto-clear timer.
      disableClearA11yAnnouncementsInTests();
    });

    // Positive control, and it must come first in spirit if not in order: every other test here
    // asserts an ABSENCE of announcements, so all of them would pass vacuously if the observer
    // never fired. This is the test that proves the instrument works, which is what gives the
    // negative assertions their meaning.
    test("the tracker records an announcement that really happens", async function (assert) {
      await render(<template><Host @variant="static" /></template>);

      const announcements = trackAnnouncements();
      const a11y = getOwner(this).lookup("service:a11y");

      a11y.announce("Twelve results", "polite");
      await settledAnnouncements();

      assert.deepEqual(
        announcements.phrases(),
        ["polite: Twelve results"],
        "a real announcement lands in the log, with its politeness"
      );

      announcements.clear();
      assert.deepEqual(announcements.phrases(), [], "clear() drops the log");

      announcements.stop();
    });

    test("stopping detaches the observer", async function (assert) {
      await render(<template><Host @variant="static" /></template>);

      const announcements = trackAnnouncements();
      announcements.stop();

      getOwner(this).lookup("service:a11y").announce("Ignored", "polite");
      await settledAnnouncements();

      assert.deepEqual(
        announcements.phrases(),
        [],
        "nothing is recorded after stop()"
      );
    });

    test("opening stays silent when it seeds a cursor", async function (assert) {
      await render(<template><Host @variant="static" /></template>);

      const announcements = trackAnnouncements();

      await click("[role='combobox']");
      await settledAnnouncements();

      // The seeded row announces itself with its own position ("1 of 3", from
      // aria-posinset/aria-setsize), so a count fired at the same moment is a second message
      // competing for one voice — and assistive tech speaks one and drops the other.
      assert.deepEqual(
        announcements.phrases(),
        [],
        "a select that opens onto a row announces nothing over it"
      );

      announcements.stop();
    });

    test("a count is announced politely, never assertively", async function (assert) {
      await render(<template><Host @variant="typeahead" /></template>);

      const announcements = trackAnnouncements();

      await click("[role='combobox']");
      await fillIn(".d-combobox__input", "an");
      await settledAnnouncements();

      assert.strictEqual(
        announcements.count("assertive"),
        0,
        "a result count never interrupts"
      );

      announcements.stop();
    });

    test("navigating rows does not announce", async function (assert) {
      await render(<template><Host @variant="static" /></template>);

      await click("[role='combobox']");
      await settledAnnouncements();

      const announcements = trackAnnouncements();

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      await settledAnnouncements();

      // Moving the cursor is a state change the platform already reports through
      // aria-activedescendant. Announcing it as well says everything twice.
      assert.deepEqual(
        announcements.phrases(),
        [],
        "arrow navigation is carried by the cursor, not by a live region"
      );

      announcements.stop();
    });

    test("the tracker fails loudly when the live regions are absent", async function (assert) {
      // Guards the helper itself. Without this, a test that forgot <A11yLiveRegions /> would report
      // an empty log and pass — silence and a broken component would be indistinguishable, which is
      // the exact trap the styleguide probe fell into.
      await render(
        <template>
          <DSelect @items={{ITEMS}} @placeholder="Pick one" />
        </template>
      );

      assert.throws(
        () => trackAnnouncements(),
        /is not in the DOM/,
        "tracking without the shared regions is an error, not silence"
      );
    });
  }
);
