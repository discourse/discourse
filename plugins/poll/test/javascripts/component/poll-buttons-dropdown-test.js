import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";

module("Poll | Component | poll-buttons-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders a clickable dropdown menu with a close option", async function (assert) {
    this.setProperties({
      closed: false,
      voters: [],
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

    assert.strictEqual(count("li.dropdown-menu__item"), 1);

    assert.strictEqual(
      query("li.dropdown-menu__item span").textContent.trim(),
      I18n.t("poll.close.label"),
      "displays the poll Close action"
    );
  });
});
