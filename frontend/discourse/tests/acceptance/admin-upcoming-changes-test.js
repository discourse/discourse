import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function buildChange(setting, status, impactType, impactRole, enabledFor) {
  return {
    setting,
    humanized_name: setting,
    description: setting,
    plugin: null,
    value: enabledFor === "everyone",
    dependents: [],
    overriding_defaults: false,
    groups: "",
    upcoming_change: {
      status,
      impact: `${impactType},${impactRole}`,
      impact_type: impactType,
      impact_role: impactRole,
      enabled_for: enabledFor,
    },
  };
}

acceptance("Admin - Upcoming Changes - URL filters", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/config/upcoming-changes", () =>
      helper.response({
        upcoming_changes: [
          buildChange(
            "alpha_composer",
            "alpha",
            "other",
            "moderators",
            "no_one"
          ),
          buildChange(
            "beta_sidebar",
            "beta",
            "feature",
            "all_members",
            "everyone"
          ),
          buildChange(
            "stable_defaults",
            "stable",
            "site_setting_default",
            "staff",
            "everyone"
          ),
        ],
      })
    );
  });

  test("preserves the legacy changeNamesFilter parameter", async function (assert) {
    await visit(
      "/admin/config/upcoming-changes?changeNamesFilter=alpha_composer,beta_sidebar"
    );

    assert
      .dom(".d-filter-controls__input")
      .hasValue("alpha_composer,beta_sidebar");
    assert.dom(".upcoming-change-row").exists({ count: 2 });

    await fillIn(".d-filter-controls__input", "beta_sidebar");
    assert.strictEqual(
      currentURL(),
      "/admin/config/upcoming-changes?changeNamesFilter=beta_sidebar"
    );
  });

  test("re-seeds filters on a same-route transition", async function (assert) {
    await visit(
      "/admin/config/upcoming-changes?changeNamesFilter=alpha_composer"
    );
    await visit("/admin/config/upcoming-changes?status=stable");

    assert.dom(".d-filter-controls__input").hasValue("");
    assert.dom(".d-filter-controls__dropdown--status").hasValue("stable");
    assert
      .dom(".upcoming-change-row[data-upcoming-change='stable_defaults']")
      .exists();
  });

  test("reset removes every owned parameter", async function (assert) {
    await visit(
      "/admin/config/upcoming-changes?changeNamesFilter=beta&status=beta&type=feature&impactRole=all_members&enabled=enabled"
    );

    assert.dom(".upcoming-change-row").exists({ count: 1 });
    await click(".d-filter-controls__reset");

    assert.strictEqual(currentURL(), "/admin/config/upcoming-changes");
    assert.dom(".d-filter-controls__input").hasValue("");
    assert.dom(".d-filter-controls__dropdown--status").hasValue("all");
    assert.dom(".upcoming-change-row").exists({ count: 3 });
  });
});
