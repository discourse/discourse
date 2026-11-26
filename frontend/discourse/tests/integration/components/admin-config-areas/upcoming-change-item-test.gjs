import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UpcomingChangeItem from "discourse/admin/components/admin-config-areas/upcoming-change-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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

function chip(name) {
  return `.d-multi-select-trigger__selected-item[title="${name}"]`;
}

async function openGroupSelector() {
  if (!document.querySelector(".d-multi-select__content")) {
    await click(".upcoming-change__group-selector");
  }
}

async function selectGroup(name) {
  await openGroupSelector();
  await click(`.d-multi-select__result[title="${name}"]`);
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
    { allow: ["everyone"], groups: [], locked: true },
    { allow: ["staff"], groups: ["staff"], locked: true },
    { allow: ["staff", "specific_groups"], groups: ["staff"], locked: false },
    { allow: undefined, groups: [], locked: false },
  ].forEach(({ allow, groups, locked }) => {
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
      assert.dom(".upcoming-change__edit-groups").doesNotExist();
      assert.dom(".upcoming-change__group-selector").exists();
      assert
        .dom(".upcoming-change__save-groups")
        .exists({ count: locked ? 0 : 1 });
      await click(".upcoming-change__enabled");
      assert.deepEqual(requests, [
        { enabled: true, setting_name: "test_setting", group_names: groups },
      ]);
      assert
        .dom(".upcoming-change__enabled")
        .hasAttribute("aria-checked", "true");
    });
  });

  [
    { role: "all_members", groups: ["logged_in_users", "anonymous_users"] },
    { role: "staff", groups: ["staff"] },
    { role: "admins", groups: ["admins"] },
    { role: "developers", groups: ["admins"] },
    { role: "moderators", groups: ["moderators"] },
  ].forEach(({ role, groups }) => {
    test(`an unscoped change shows a locked audience for ${role}`, async function (assert) {
      const change = buildChange({
        value: false,
        upcoming_change: {
          status: "beta",
          impact_role: role,
          enabled_for: "no_one",
          allow_enabled_for: ["everyone"],
        },
      });
      await render(
        <template>
          <table><tbody><UpcomingChangeItem
                @change={{change}}
              /></tbody></table>
        </template>
      );
      assert.deepEqual(
        [
          ...document.querySelectorAll(
            ".d-multi-select-trigger__selected-item"
          ),
        ].map((el) => el.title),
        groups
      );
      groups.forEach((group) =>
        assert.dom(`${chip(group)} .d-icon-lock`).exists()
      );
      assert.dom(".upcoming-change__save-groups").doesNotExist();
      assert
        .dom(".upcoming-change__groups-description")
        .hasText(i18n("admin.upcoming_changes.audience_locked"));
    });
  });

  test("a scopable change defaults to its role audience and stores it as unrestricted", async function (assert) {
    const requests = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      requests.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    pretender.get("/groups/search.json", () =>
      response([
        { id: 20, name: "admin_team" },
        { id: 1, name: "admins" },
      ])
    );
    const change = buildChange({
      upcoming_change: {
        status: "beta",
        impact_role: "admins",
        enabled_for: "everyone",
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    assert.dom(chip("admins")).exists();
    assert.dom(chip("logged_in_users")).doesNotExist();
    assert.dom(".upcoming-change__save-groups").isDisabled();

    await selectGroup("admin_team");
    await click(chip("admins"));
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests.at(-1).group_names, ["admin_team"]);

    await selectGroup("admins");
    await click(chip("admin_team"));
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests.at(-1).group_names, []);
    assert.dom(chip("admins")).exists();
  });

  test("the audience stays visible while the change is disabled", async function (assert) {
    const change = buildChange({
      value: false,
      upcoming_change: { status: "beta", enabled_for: "no_one" },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "false");
    assert.dom(chip("logged_in_users")).isVisible();
    assert.dom(chip("anonymous_users")).isVisible();
  });

  test("the default audience shows both groups without saving", async function (assert) {
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
    assert.dom(chip("logged_in_users")).exists();
    assert.dom(chip("anonymous_users")).exists();
    assert.strictEqual(saves, 0);
    assert.strictEqual(change.groups, "");
    assert.dom(".upcoming-change__save-groups").isDisabled();
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
    await click(chip("anonymous_users"));
    assert.strictEqual(
      requests.length,
      0,
      "removing a group only changes the draft"
    );
    assert.dom(".upcoming-change__save-groups").isNotDisabled();
    await click(".upcoming-change__save-groups");
    assert.deepEqual(requests[0].group_names, ["logged_in_users"]);
    assert.dom(".upcoming-change__save-groups").isDisabled();
    await click(chip("logged_in_users"));
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
    await selectGroup("team");
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

  test("staff cannot be removed", async function (assert) {
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
    assert
      .dom(".upcoming-change__groups-description")
      .hasText(i18n("admin.upcoming_changes.staff_always_included"));
    assert.dom(`${chip("staff")} .d-icon-lock`).exists();
    assert.dom(chip("staff")).hasAria("disabled", "true");
    await click(chip("staff"));
    assert.strictEqual(saves, 0);
    assert.dom(".upcoming-change__save-groups").isDisabled();
    assert.dom(chip("staff")).exists();
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
    assert.dom(chip("staff")).exists();
    assert.dom(chip("logged_in_users")).doesNotExist();
    assert.dom(chip("anonymous_users")).doesNotExist();
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
    await selectGroup("anonymous_users");
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
    await click(chip("staff"));
    await click(".upcoming-change__save-groups");
    assert.dom(chip("staff")).doesNotExist("retains the draft for retry");
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
    await click(chip("staff"));
    await click(".upcoming-change__enabled");
    assert.deepEqual(requests, [
      { enabled: true, setting_name: "test_setting", group_names: ["staff"] },
    ]);
    assert.dom(chip("staff")).doesNotExist();
    assert.dom(".upcoming-change__save-groups").isNotDisabled();
  });
  test("linked audience edits save only the group setting and never toggle the change", async function (assert) {
    const toggles = [],
      groupSaves = [];
    const descriptor = {
      setting: "feature_allowed_groups",
      value: "3",
      mandatory_values: "",
      disallowed_groups: "0",
    };
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      toggles.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    pretender.put("/admin/config/upcoming-changes/groups", (request) => {
      groupSaves.push(JSON.parse(request.requestBody));
      return response({
        success: "OK",
        groups: "staff,team",
        group_setting: { ...descriptor, value: "3|20" },
      });
    });
    pretender.get("/groups/search.json", () =>
      response([{ id: 20, name: "team" }])
    );
    const change = buildChange({
      groups: "staff",
      value: false,
      group_setting: descriptor,
      upcoming_change: {
        status: "beta",
        enabled_for: "no_one",
        group_setting: "feature_allowed_groups",
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await selectGroup("team");
    assert.strictEqual(groupSaves.length, 0);
    await click(".upcoming-change__save-groups");
    assert.deepEqual(groupSaves, [
      { setting: "test_setting", group_names: ["staff", "team"] },
    ]);
    assert.strictEqual(toggles.length, 0);
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "false");
    await click(".upcoming-change__enabled");
    assert.deepEqual(toggles, [
      { setting_name: "test_setting", enabled: true },
    ]);
    assert.strictEqual(groupSaves.length, 1);
  });

  test("an empty linked audience cannot be saved and directs admins to the toggle", async function (assert) {
    let saves = 0;
    pretender.put("/admin/config/upcoming-changes/groups", () => {
      saves++;
      return response({ success: "OK" });
    });
    const change = buildChange({
      groups: "staff",
      group_setting: { setting: "feature_allowed_groups", value: "3" },
      upcoming_change: {
        status: "beta",
        enabled_for: "staff",
        group_setting: "feature_allowed_groups",
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    await click(chip("staff"));
    assert.dom(".upcoming-change__save-groups").isDisabled();
    assert
      .dom(".upcoming-change__groups-description")
      .hasText(i18n("admin.upcoming_changes.toggle_instead_of_empty_groups"));
    assert
      .dom(".upcoming-change__enabled")
      .hasAttribute("aria-checked", "true");
    assert.strictEqual(saves, 0);
    assert.strictEqual(change.groups, "staff");
  });

  test("linked empty settings are shown as empty without synthetic prefill", async function (assert) {
    const toggles = [];
    pretender.put("/admin/config/upcoming-changes/toggle", (request) => {
      toggles.push(JSON.parse(request.requestBody));
      return response({ success: "OK" });
    });
    const change = buildChange({
      groups: "",
      group_setting: { setting: "feature_allowed_groups", value: "" },
      upcoming_change: {
        status: "beta",
        enabled_for: "groups",
        group_setting: "feature_allowed_groups",
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    assert.dom(".d-multi-select-trigger__selected-item").doesNotExist();
    assert.dom(".upcoming-change__save-groups").isDisabled();
    await click(".upcoming-change__enabled");
    await click(".upcoming-change__enabled");
    assert.deepEqual(toggles, [
      { setting_name: "test_setting", enabled: false },
      { setting_name: "test_setting", enabled: true },
    ]);
    assert.strictEqual(change.groups, "");
  });

  test("linked mandatory and disallowed groups come from the site setting", async function (assert) {
    pretender.get("/groups/search.json", () =>
      response([
        { id: 4, name: "anonymous_users" },
        { id: 20, name: "team" },
      ])
    );
    const change = buildChange({
      groups: "staff",
      group_setting: {
        setting: "feature_allowed_groups",
        value: "3",
        mandatory_values: "3",
        disallowed_groups: "0|4",
      },
      upcoming_change: {
        status: "beta",
        enabled_for: "staff",
        group_setting: "feature_allowed_groups",
      },
    });
    await render(
      <template>
        <table><tbody><UpcomingChangeItem @change={{change}} /></tbody></table>
      </template>
    );
    assert.dom(`${chip("staff")} .d-icon-lock`).exists();
    await openGroupSelector();
    assert
      .dom('.d-multi-select__result[title="anonymous_users"]')
      .doesNotExist();
    assert.dom('.d-multi-select__result[title="team"]').exists();
  });
});
