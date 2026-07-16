import { fillIn, render } from "@ember/test-helpers";
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

  test("selecting staff on a change that excludes 'everyone' saves the staff group before enabling", async function (assert) {
    const requests = [];
    let groupSaved = false;

    pretender.put("/admin/config/upcoming-changes/groups", () => {
      requests.push("groups");
      groupSaved = true;
      return response({ success: "OK" });
    });
    pretender.put("/admin/config/upcoming-changes/toggle", () => {
      requests.push("toggle");
      if (!groupSaved) {
        return response(422, { errors: ["everyone is not an allowed target"] });
      }
      return response({ success: "OK" });
    });

    const change = buildChange({
      setting: "reporting_improvements",
      value: false,
      upcoming_change: {
        status: "beta",
        impact: "feature,staff",
        impact_type: "feature",
        impact_role: "staff",
        enabled_for: "no_one",
        allow_enabled_for: ["staff", "specific_groups"],
      },
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    await fillIn(".upcoming-change__enabled-for", "staff");

    assert.deepEqual(
      requests,
      ["groups", "toggle"],
      "persists the staff group first, so the toggle passes instead of 422ing"
    );
    assert
      .dom(".upcoming-change__enabled-for")
      .hasValue("staff", "keeps staff selected");
  });

  test("selecting everyone toggles the change then clears any groups", async function (assert) {
    const requests = [];

    pretender.put("/admin/config/upcoming-changes/toggle", () => {
      requests.push("toggle");
      return response({ success: "OK" });
    });
    pretender.put("/admin/config/upcoming-changes/groups", () => {
      requests.push("groups");
      return response({ success: "OK" });
    });

    const change = buildChange({
      value: false,
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

    await fillIn(".upcoming-change__enabled-for", "everyone");

    assert.deepEqual(
      requests,
      ["toggle", "groups"],
      "enables first then clears groups when 'everyone' is allowed"
    );
    assert
      .dom(".upcoming-change__enabled-for")
      .hasValue("everyone", "keeps everyone selected");
  });
});
