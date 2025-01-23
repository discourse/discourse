import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

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

    assert.dom("li.dropdown-menu__item").exists({ count: 2 });
    assert
      .dom("li.dropdown-menu__item span")
      .hasText(
        i18n("poll.export-results.label"),
        "displays the poll Export action"
      );
  });

  test("Renders a show-tally button when poll is a bar chart", async function (assert) {
    this.setProperties({
      closed: false,
      voters: 2,
      isStaff: false,
      isMe: false,
      topicArchived: false,
      groupableUserFields: ["stuff"],
      isAutomaticallyClosed: false,
      dropDownClick: () => {},
      availableDisplayMode: "showTally",
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
      @availableDisplayMode={{this.availableDisplayMode}}
    />`);

    await click(".widget-dropdown-header");

    assert.dom("li.dropdown-menu__item").exists({ count: 2 });
    assert
      .dom("li.dropdown-menu__item span")
      .hasText(
        i18n("poll.show-tally.label"),
        "displays the show absolute button"
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

    assert.dom(".widget-dropdown-header").doesNotExist();
    assert.dom("button.widget-button").exists({ count: 1 });
    assert
      .dom("button.widget-button span.d-button-label")
      .hasText(
        i18n("poll.breakdown.breakdown"),
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

    assert.dom(".widget-dropdown-header").doesNotExist();
    assert.dom("button.widget-button").doesNotExist();
  });
});
