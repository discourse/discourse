import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module("Poll | Component | poll-buttons-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders a clickable dropdown menu with a close option", async function (assert) {
    this.siteSettings.data_explorer_enabled = true;
    this.siteSettings.poll_export_data_explorer_query_id = 18;
    this.currentUser.setProperties({ admin: true });

    this.setProperties({
      closed: true,
      voters: 3,
      isStaff: true,
      isMe: false,
      topicArchived: false,
      groupableUserFields: [],
      isAutomaticallyClosed: false,
      dropDownClick: () => {},
    });

    await render(hbs`<PollButtonsDropdown
      @closed={{this.closed}}
      @voters={{this.voters}}
      @isStaff={{this.isStaff}}
      @isMe={{this.isMe}}
      @topicArchived={{this.topicArchived}}
      @groupableUserFields={{this.groupableUserFields}}
      @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
      @dropDownClick={{this.dropDownClick}}
    />`);

    await click(".widget-dropdown-header");

    assert.strictEqual(count("li.dropdown-menu__item"), 2);

    assert.strictEqual(
      query("li.dropdown-menu__item span").textContent.trim(),
      I18n.t("poll.export-results.label"),
      "displays the poll Export action"
    );
  });

  test("Renders a single button when there is only one authorised action", async function (assert) {
    this.setProperties({
      closed: false,
      voters: 2,
      isStaff: false,
      isMe: false,
      topicArchived: false,
      groupableUserFields: ["stuff"],
      isAutomaticallyClosed: false,
      dropDownClick: () => {},
    });

    await render(hbs`<PollButtonsDropdown
      @closed={{this.closed}}
      @voters={{this.voters}}
      @isStaff={{this.isStaff}}
      @isMe={{this.isMe}}
      @topicArchived={{this.topicArchived}}
      @groupableUserFields={{this.groupableUserFields}}
      @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
      @dropDownClick={{this.dropDownClick}}
    />`);

    assert.strictEqual(count(".widget-dropdown-header"), 0);

    assert.strictEqual(count("button.widget-button"), 1);

    assert.strictEqual(
      query("button.widget-button span.d-button-label").textContent.trim(),
      I18n.t("poll.breakdown.breakdown"),
      "displays the poll Close action"
    );
  });

  test("Doesn't render a button when user has no authorised actions", async function (assert) {
    this.setProperties({
      closed: false,
      voters: 0,
      isStaff: false,
      isMe: false,
      topicArchived: false,
      groupableUserFields: [],
      isAutomaticallyClosed: false,
      dropDownClick: () => {},
    });

    await render(hbs`<PollButtonsDropdown
      @closed={{this.closed}}
      @voters={{this.voters}}
      @isStaff={{this.isStaff}}
      @isMe={{this.isMe}}
      @topicArchived={{this.topicArchived}}
      @groupableUserFields={{this.groupableUserFields}}
      @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
      @dropDownClick={{this.dropDownClick}}
    />`);

    assert.strictEqual(count(".widget-dropdown-header"), 0);

    assert.strictEqual(count("button.widget-button"), 0);
  });
});
