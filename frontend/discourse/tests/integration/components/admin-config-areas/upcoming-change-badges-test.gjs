import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UpcomingChangeBadges from "discourse/admin/components/admin-config-areas/upcoming-change-badges";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

function buildUpcomingChange(overrides = {}) {
  return {
    status: "beta",
    impact: "feature,all_members",
    impact_type: "feature",
    impact_role: "all_members",
    enabled_for: "everyone",
    ...overrides,
  };
}

module("Integration | Component | UpcomingChangeBadges", function (hooks) {
  setupRenderingTest(hooks);

  test("renders status, impact type, and impact role badges", async function (assert) {
    const upcomingChange = buildUpcomingChange();

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert.dom(".upcoming-change__badges").exists();
    assert
      .dom(".upcoming-change__badge.--status-beta")
      .exists("renders the status badge with the status modifier class");
    assert
      .dom(".upcoming-change__badge.--impact-type-feature")
      .exists("renders the impact type badge");
    assert
      .dom(".upcoming-change__badge.--impact-role-all_members")
      .exists("renders the impact role badge");
  });

  test("status badge uses the tooltip trigger class", async function (assert) {
    const upcomingChange = buildUpcomingChange({ status: "experimental" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--status-experimental.--has-tooltip")
      .exists();
    assert.dom(".upcoming-change__badge-info").exists("renders the info icon");
  });

  test("renders feature impact type with wand icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_type: "feature" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-type-feature")
      .exists()
      .containsText(i18n("admin.upcoming_changes.impact_types.feature_type"));
    assert
      .dom(
        ".upcoming-change__badge.--impact-type-feature .d-icon-wand-magic-sparkles"
      )
      .exists();
  });

  test("renders other impact type with discourse-other-tab icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_type: "other" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-type-other")
      .exists()
      .containsText(i18n("admin.upcoming_changes.impact_types.other_type"));
    assert
      .dom(
        ".upcoming-change__badge.--impact-type-other .d-icon-discourse-other-tab"
      )
      .exists();
  });

  test("renders site setting default impact type with gear icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({
      impact_type: "site_setting_default",
    });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-type-site_setting_default")
      .exists()
      .containsText(
        i18n("admin.upcoming_changes.impact_types.site_setting_default_type")
      );
    assert
      .dom(
        ".upcoming-change__badge.--impact-type-site_setting_default .d-icon-gear"
      )
      .exists();
  });

  test("renders admins impact role with shield icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_role: "admins" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-role-admins")
      .exists()
      .containsText(i18n("admin.upcoming_changes.impact_roles.admins"));
    assert
      .dom(".upcoming-change__badge.--impact-role-admins .d-icon-shield-halved")
      .exists();
  });

  test("renders moderators impact role with shield icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_role: "moderators" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(
        ".upcoming-change__badge.--impact-role-moderators .d-icon-shield-halved"
      )
      .exists();
  });

  test("renders staff impact role with shield icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_role: "staff" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-role-staff .d-icon-shield-halved")
      .exists();
  });

  test("renders all_members impact role with users icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_role: "all_members" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-role-all_members .d-icon-users")
      .exists();
  });

  test("renders developers impact role with code icon", async function (assert) {
    const upcomingChange = buildUpcomingChange({ impact_role: "developers" });

    await render(
      <template>
        <UpcomingChangeBadges @upcomingChange={{upcomingChange}} />
      </template>
    );

    assert
      .dom(".upcoming-change__badge.--impact-role-developers .d-icon-code")
      .exists();
  });
});
