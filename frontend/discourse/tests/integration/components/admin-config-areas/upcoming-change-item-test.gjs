import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import UpcomingChangeItem from "discourse/admin/components/admin-config-areas/upcoming-change-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function buildChange(overrides = {}) {
  return {
    setting: "test_setting",
    humanized_name: "Test setting",
    description: "A test setting",
    value: true,
    plugin: null,
    dependents: [],
    overriding_defaults: false,
    groups: "",
    upcoming_change: {
      status: "beta",
      impact: "feature,all_members",
      impact_type: "feature",
      impact_role: "all_members",
      enabled_for: "everyone",
    },
    ...overrides,
  };
}

module("Integration | Component | UpcomingChangeItem", function (hooks) {
  setupRenderingTest(hooks);

  test("renders dependent settings link when dependents exist and enabled", async function (assert) {
    const change = buildChange({
      dependents: ["other_setting"],
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__dependents a")
      .exists("shows the dependent settings link");
  });

  test("does not render dependent settings link when enabled_for is no_one", async function (assert) {
    const change = buildChange({
      dependents: ["other_setting"],
      upcoming_change: {
        status: "beta",
        impact: "feature,all_members",
        impact_type: "feature",
        impact_role: "all_members",
        enabled_for: "no_one",
      },
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__dependents")
      .doesNotExist("does not show the dependent settings link");
  });

  test("renders default override setting link when overriding defaults and enabled", async function (assert) {
    const change = buildChange({
      overriding_defaults: true,
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__default-override-setting a")
      .exists("shows the default override setting link");
  });

  test("does not render default override setting link when overriding defaults is false", async function (assert) {
    const change = buildChange();

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__default-override-setting")
      .doesNotExist("does not show the default override setting link");
  });

  test("does not render default override setting link when enabled_for is no_one", async function (assert) {
    const change = buildChange({
      overriding_defaults: true,
      upcoming_change: {
        status: "beta",
        impact: "feature,all_members",
        impact_type: "feature",
        impact_role: "all_members",
        enabled_for: "no_one",
      },
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__default-override-setting")
      .doesNotExist(
        "does not show the default override setting link when disabled"
      );
  });

  test("renders setting links in the description and rewrites their href via the modifier", async function (assert) {
    const rewrittenURL = "/admin/config/category/settings?filter=other_setting";
    const dataSource = this.owner.lookup("service:admin-search-data-source");
    dataSource.urlForSetting = ({ setting }) =>
      setting === "other_setting" ? rewrittenURL : null;

    const change = buildChange({
      description:
        'Enables the thing. Note that <a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=other_setting" data-setting-name="other_setting" data-setting-category="category">Other setting</a> must be enabled.',
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__description a.site-setting-link")
      .exists("renders the setting link as an anchor element")
      .hasText("Other setting", "renders the link text")
      .hasAttribute(
        "href",
        rewrittenURL,
        "rewrites the href to the setting's config page via the modifier"
      );

    assert
      .dom(".upcoming-change__description")
      .doesNotIncludeText(
        "<a",
        "does not render the link markup as escaped text"
      );
  });

  test("renders the permanent soon notice when status is stable", async function (assert) {
    const change = buildChange({
      upcoming_change: {
        status: "stable",
        impact: "feature,all_members",
        impact_type: "feature",
        impact_role: "all_members",
        enabled_for: "everyone",
      },
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__status-notice")
      .hasText(
        new RegExp(i18n("admin.upcoming_changes.permanent_soon_notice")),
        "shows the permanent soon notice"
      );
  });

  test("does not render the permanent soon notice when permanent_warning is false", async function (assert) {
    const change = buildChange({
      upcoming_change: {
        status: "stable",
        impact: "site_setting_default,all_members",
        impact_type: "site_setting_default",
        impact_role: "all_members",
        permanent_warning: false,
        enabled_for: "everyone",
      },
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__status-notice")
      .doesNotExist(
        "does not show the permanent soon notice when the change opts out of it"
      );
  });

  ["experimental", "alpha", "beta"].forEach((status) => {
    test(`does not render the permanent soon notice when status is ${status}`, async function (assert) {
      const change = buildChange({
        upcoming_change: {
          status,
          impact: "feature,all_members",
          impact_type: "feature",
          impact_role: "all_members",
          enabled_for: "everyone",
        },
      });

      await render(
        <template>
          <table>
            <tbody><UpcomingChangeItem @change={{change}} /></tbody>
          </table>
        </template>
      );

      assert
        .dom(".upcoming-change__status-notice")
        .doesNotExist(
          `does not show the permanent soon notice for ${status} changes`
        );
    });
  });

  [
    { allow: ["everyone"], groups: [], gear: false },
    { allow: ["staff"], groups: ["staff"], gear: false },
    { allow: ["staff", "specific_groups"], groups: ["staff"], gear: true },
    { allow: undefined, groups: [], gear: true },
  ].forEach(({ allow, groups, gear }) => {
    test(`toggle enables with the correct audience for ${allow || "default"}`, async function (assert) {
      const requests = [];
      pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
        requests.push(JSON.parse(request.requestBody));
        return response({ success: "OK" });
      });
      const change = buildChange({
        value: false,
        upcoming_change: {
          status: "beta",
          enabled_for: "no_one",
          allow_enabled_for: allow,
        },
      });
      await render(
        <template>
          <table><tbody><UpcomingChangeItem
                @change={{change}}
              /></tbody></table>
        </template>
      );
      assert
        .dom(".upcoming-change__enabled")
        .hasAttribute("aria-checked", "false");
      assert
        .dom(".upcoming-change__edit-groups")
        .exists({ count: gear ? 1 : 0 });
      await click(".upcoming-change__enabled");
      assert.deepEqual(requests, [
        { enabled: true, setting_name: "test_setting", group_names: groups },
      ]);
      assert
        .dom(".upcoming-change__enabled")
        .hasAttribute("aria-checked", "true");
    });
  });

  test("opening the default audience prefills both groups without saving", async function (assert) {
    let saves = 0;
    pretender.put("/admin/config/upcoming-changes/toggle", () => {
      saves++;
      return response({ success: "OK" });
    });
    const change = buildChange();
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    assert.dom('.selected-choice[data-name="logged_in_users"]').exists();
    assert.dom('.selected-choice[data-name="anonymous_users"]').exists();
    await click(".upcoming-change__edit-groups");
    assert.strictEqual(saves, 0);
    assert.strictEqual(change.groups, "");
    assert.dom(".upcoming-change__save-groups").doesNotExist();
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "true");
  });

  test("audience edits are only persisted with the save button", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    const change = buildChange();
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    await click('.selected-choice[data-name="anonymous_users"]');
    assert.strictEqual(
      requests.length,
      0,
      "removing a group only changes the draft"
    );
    assert.dom(".upcoming-change__save-groups").isNotDisabled();
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests[0].group_names, ["logged_in_users"]);
    assert.dom(".upcoming-change__save-groups").isDisabled();
    await click('.selected-choice[data-name="logged_in_users"]');
    assert.strictEqual(requests.length, 1);
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests[1], {
      enabled: false,
      setting_name: "test_setting",
      group_names: [],
    });
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "false");
  });

  test("turning off preserves saved groups and turning back on restores them", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    const change = buildChange({
      groups: "staff",
      upcoming_change: { status: "beta", enabled_for: "staff" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__enabled");
    await click(".upcoming-change__enabled");
    assert.deepEqual(requests, [
      { enabled: false, setting_name: "test_setting" },
      { enabled: true, setting_name: "test_setting", group_names: ["staff"] },
    ]);
  });

  test("a groups-only change waits for an audience before enabling", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    pretender.get("/groups/search.json", () =>
      response([{ id: 10, name: "team" }])
    );
    const change = buildChange({
      value: false,
      upcoming_change: {
        status: "beta",
        enabled_for: "no_one",
        allow_enabled_for: ["specific_groups"],
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__enabled");
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "false");
    assert.strictEqual(requests.length, 0);
    const chooser = selectKit(".email-group-user-chooser");
    await chooser.expand();
    await chooser.selectRowByValue("team");
    assert.strictEqual(
      requests.length,
      0,
      "selecting a group waits for confirmation"
    );
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests, [
      { enabled: true, setting_name: "test_setting", group_names: ["team"] },
    ]);
  });

  test("staff cannot be removed by clicking or keyboard", async function (assert) {
    let saves = 0;
    pretender.put("/admin/config/upcoming-changes/toggle", () => {
      saves++;
      return response({ success: "OK" });
    });
    pretender.get("/groups/search.json", () => response([]));
    const change = buildChange({
      groups: "staff",
      upcoming_change: {
        status: "beta",
        enabled_for: "staff",
        allow_enabled_for: ["staff", "specific_groups"],
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    assert
      .dom(".upcoming-change__groups-description")
      .hasText(i18n("admin.upcoming_changes.staff_always_included"));
    assert.dom('.selected-choice[data-name="staff"]').isDisabled();
    assert.dom('.selected-choice[data-name="staff"] .d-icon-lock').exists();
    const chooser = selectKit(".email-group-user-chooser");
    await chooser.expand();
    await triggerKeyEvent(
      ".email-group-user-chooser input",
      "keydown",
      "Backspace"
    );
    await triggerKeyEvent(
      ".email-group-user-chooser input",
      "keydown",
      "Backspace"
    );
    assert.strictEqual(saves, 0);
    assert.dom('.selected-choice[data-name="staff"]').exists();
  });
  test("saved groups take precedence over the unrestricted default audience", async function (assert) {
    const change = buildChange({
      groups: "staff",
      upcoming_change: { status: "beta", enabled_for: "staff" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    assert.dom('.selected-choice[data-name="staff"]').exists();
    assert.dom('.selected-choice[data-name="logged_in_users"]').doesNotExist();
    assert.dom('.selected-choice[data-name="anonymous_users"]').doesNotExist();
  });

  test("restoring both default groups clears stored restrictions", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    pretender.get("/groups/search.json", () =>
      response([{ id: 4, name: "anonymous_users" }])
    );
    const change = buildChange({
      groups: "logged_in_users",
      upcoming_change: { status: "beta", enabled_for: "groups" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    const chooser = selectKit(".email-group-user-chooser");
    await chooser.expand();
    await chooser.selectRowByValue("anonymous_users");
    assert.strictEqual(requests.length, 0);
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests.at(-1), {
      enabled: true,
      setting_name: "test_setting",
      group_names: [],
    });
    assert.strictEqual(change.groups, "");
  });

  test("failed saves restore the previous toggle and audience", async function (assert) {
    pretender.put("/admin/config/upcoming-changes/toggle", () =>
      response(422, { errors: ["Could not save"] })
    );
    const change = buildChange({
      groups: "staff",
      upcoming_change: { status: "beta", enabled_for: "staff" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__enabled");
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "true");
    assert.strictEqual(change.groups, "staff");
    await click(".upcoming-change__edit-groups");
    await click('.selected-choice[data-name="staff"]');
    await click(".upcoming-change__save-groups");
    assert
      .dom('.selected-choice[data-name="staff"]')
      .doesNotExist("retains the draft for retry");
    assert.dom(".upcoming-change__save-groups").isNotDisabled();
    assert.strictEqual(change.groups, "staff", "saved audience is unchanged");
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "true");
    this.owner.lookup("service:dialog").cancel();
  });
  test("the main toggle uses the saved audience without applying pending group edits", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    const change = buildChange({
      value: false,
      groups: "staff",
      upcoming_change: { status: "beta", enabled_for: "no_one" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(".upcoming-change__edit-groups");
    await click('.selected-choice[data-name="staff"]');
    await click(".upcoming-change__enabled");
    assert.deepEqual(requests, [
      { enabled: true, setting_name: "test_setting", group_names: ["staff"] },
    ]);
    assert.dom('.selected-choice[data-name="staff"]').doesNotExist();
    assert.dom(".upcoming-change__save-groups").isNotDisabled();
  });
});
