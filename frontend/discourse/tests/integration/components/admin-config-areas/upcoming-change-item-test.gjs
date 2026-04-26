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
    related: null,
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

  test("renders related setting link when related exists and enabled", async function (assert) {
    const change = buildChange({
      related: "some_other_setting",
    });

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__related a")
      .exists("shows the related setting link");
  });

  test("does not render related setting link when related is null", async function (assert) {
    const change = buildChange();

    await render(
      <template>
        <table>
          <tbody><UpcomingChangeItem @change={{change}} /></tbody>
        </table>
      </template>
    );

    assert
      .dom(".upcoming-change__related")
      .doesNotExist("does not show the related setting link");
  });

  test("does not render related setting link when enabled_for is no_one", async function (assert) {
    const change = buildChange({
      related: "some_other_setting",
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
      .dom(".upcoming-change__related")
      .doesNotExist("does not show the related setting link when disabled");
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
