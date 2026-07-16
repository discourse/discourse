import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | A11y | LiveRegions", function (hooks) {
  setupRenderingTest(hooks);

  test("renders polite and assertive live regions", async function (assert) {
    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .exists("polite announcements element exists");
    assert
      .dom("#a11y-announcements-assertive")
      .exists("assertive announcements element exists");

    assert.dom("#a11y-announcements-polite").hasAttribute("role", "status");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-live", "polite");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-atomic", "true");

    assert.dom("#a11y-announcements-assertive").hasAttribute("role", "alert");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-live", "assertive");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-atomic", "true");
  });

  test("displays assertive messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test assertive message", "assertive", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-assertive")
      .hasText("Test assertive message", "displays assertive message");
  });

  test("displays polite messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test polite message", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Test polite message", "displays polite message");
  });

  test("composes same-type announcements made in one flush instead of clobbering", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    // Two polite announcements in the same synchronous flush — e.g. an "item added"
    // message immediately followed by a re-filtered result count. The one-message-per-type
    // live region can only show one, so without composition the second deterministically
    // clobbers the first and "Added Foo" is never announced.
    a11y.announce("Added Foo", "polite", 500);
    a11y.announce("12 results", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Added Foo. 12 results",
        "both same-flush messages are composed into one atomic announcement"
      );
  });

  test("dedupes identical same-type announcements made in one flush", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    // Two independent callers announcing the same phrase in one flush (e.g. two
    // subscribers both reporting the same result count). Repeating the identical
    // text in one atomic announcement is pure redundancy for a screen reader.
    a11y.announce("3 results", "polite", 500);
    a11y.announce("3 results", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "3 results",
        "the repeated message is announced once, not composed with itself"
      );
  });

  test("keeps polite and assertive announcements separate when made in one flush", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Polite one", "polite", 500);
    a11y.announce("Assertive one", "assertive", 500);
    a11y.announce("Polite two", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Polite one. Polite two",
        "polite messages compose among themselves"
      );
    assert
      .dom("#a11y-announcements-assertive")
      .hasText(
        "Assertive one",
        "the assertive message is not folded in with the polite ones"
      );
  });

  test("announce called during render does not trigger a backtracking assertion", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    // Mirrors DIconGridPickerContent: a getter read during render calls `announce`.
    // <A11yLiveRegions /> renders first and reads the tracked message map, so a
    // synchronous announce (write) later in the same render trips Ember's
    // backtracking-rerender assertion and breaks the render. The announcer is placed
    // AFTER the live regions to establish that read-before-write ordering.
    class RenderTimeAnnouncer extends Component {
      @service a11y;

      get announced() {
        this.a11y.announce("Announced during render", "polite", 500);
        return "";
      }

      <template>{{this.announced}}</template>
    }

    await render(
      <template>
        <A11yLiveRegions />
        <RenderTimeAnnouncer />
      </template>
    );

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        "Announced during render",
        "the render-time announcement is shown without a backtracking error"
      );
  });
});
