import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UpcomingChangeItem from "discourse/admin/components/admin-config-areas/upcoming-change-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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

  test("does not render the permanent soon notice when impact_type is site_setting_default", async function (assert) {
    const change = buildChange({
      upcoming_change: {
        status: "stable",
        impact: "site_setting_default,all_members",
        impact_type: "site_setting_default",
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
        "does not show the permanent soon notice for site setting default changes"
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
});
