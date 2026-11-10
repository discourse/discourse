import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import pretender from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";
import { i18n } from "discourse-i18n";

function stubCategory(needs, customFields) {
  needs.site({
    categories: [
      {
        id: 6,
        name: "test",
        slug: "test",
        custom_fields: customFields,
      },
    ],
  });

  needs.pretender((server, helper) => {
    server.get("/c/test/6/l/latest.json", () => {
      return helper.response(
        DiscoveryFixtures["/latest_can_create_topic.json"]
      );
    });
  });
}

acceptance("Categories for users that can assign", function (needs) {
  needs.user({ can_assign: true, can_assign_globally: true });
  needs.settings({
    assign_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: false,
  });
  stubCategory(needs, { enable_unassigned_filter: "true" });

  test("can see Unassigned button", async function (assert) {
    await visit("/c/test");

    const title = i18n("filters.unassigned.help");
    assert.dom(`#navigation-bar li[title='${title}']`).exists();
  });
});

acceptance("Categories without enable_unassigned_filter", function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: false,
  });
  stubCategory(needs, { enable_unassigned_filter: "false" });

  test("cannot see Unassigned button", async function (assert) {
    await visit("/c/test");

    const title = i18n("filters.unassigned.help");
    assert.dom(`#navigation-bar li[title='${title}']`).doesNotExist();
  });
});

acceptance("Categories when assigns are public", function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: true,
  });
  stubCategory(needs, { enable_unassigned_filter: "true" });

  test("can see Unassigned button", async function (assert) {
    await visit("/c/test");

    const title = i18n("filters.unassigned.help");
    assert.dom(`#navigation-bar li[title='${title}']`).exists();
  });
});

acceptance("Categories when assigns are private", function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: false,
  });
  stubCategory(needs, { enable_unassigned_filter: "true" });

  test("cannot see Unassigned button", async function (assert) {
    await visit("/c/test");

    const title = i18n("filters.unassigned.help");
    assert.dom(`#navigation-bar li[title='${title}']`).doesNotExist();
  });
});

acceptance("Category assign settings - new select controls", function (needs) {
  needs.user({ admin: true, can_assign: true, can_assign_globally: true });
  needs.settings({
    assign_enabled: true,
    assign_allowed_on_groups: "3",
    enable_new_select_controls: true,
  });
  needs.hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
    this.counter = sinon.stub(DeprecationCounter.prototype, "incrementCount");
  });
  needs.hooks.afterEach(function () {
    enableRaiseOnDeprecation();
  });

  test("the additional assign groups picker reports no legacy render", async function (assert) {
    await visit("/c/bug/edit/settings");

    assert.dom(".d-select.group-chooser").exists();
    assert.strictEqual(
      this.counter
        .getCalls()
        .filter(
          (call) =>
            call.args[0] === "discourse.select-kit-rollout.legacy-render"
        ).length,
      0,
      "the picker is a new select control"
    );
  });

  test("the globally allowed groups can't be removed", async function (assert) {
    await visit("/c/bug/edit/settings");

    const chip = ".group-chooser .d-select__chip[data-value='3']";
    assert.dom(chip).hasClass("--locked", "the global group is locked");
    assert
      .dom(`${chip} .d-select__chip-remove`)
      .hasAttribute("aria-disabled", "true");

    await click(`${chip} .d-select__chip-remove`);

    assert.dom(chip).exists("the global group is still held");
  });

  test("saves only the groups the category adds", async function (assert) {
    await visit("/c/bug/edit/settings");

    const groups = dSelect(".group-chooser");
    await groups.open();
    await groups.select("50");
    await groups.close();
    await click(".admin-changes-banner .btn-primary");

    const request = pretender.handledRequests.findLast(
      ({ method, requestBody }) => method === "PUT" && requestBody
    );
    assert.strictEqual(
      JSON.parse(request.requestBody).custom_fields
        .additional_assign_allowed_on_groups,
      "50",
      "the global group is left out of the saved value"
    );
  });
});
