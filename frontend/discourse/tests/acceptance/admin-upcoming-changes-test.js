import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function buildChange(
  setting,
  status,
  impactType,
  impactRole,
  enabledFor,
  statusChangedAt = null
) {
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
      status_changed_at: statusChangedAt,
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

acceptance("Admin - Upcoming Changes - Sorting", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/config/upcoming-changes", () =>
      helper.response({
        upcoming_changes: [
          buildChange(
            "beta_old",
            "beta",
            "feature",
            "all_members",
            "no_one",
            "2026-01-01T00:00:00Z"
          ),
          buildChange(
            "alpha_recent",
            "alpha",
            "feature",
            "all_members",
            "no_one",
            "2026-06-01T00:00:00Z"
          ),
          buildChange(
            "experimental_untracked",
            "experimental",
            "feature",
            "all_members",
            "no_one"
          ),
          buildChange(
            "stable_middle",
            "stable",
            "feature",
            "all_members",
            "everyone",
            "2026-03-01T00:00:00Z"
          ),
        ],
      })
    );
  });

  async function chooseSort(value) {
    await click(".upcoming-changes__sort-trigger");
    await click(`.upcoming-changes__sort-option[data-sort='${value}']`);
  }

  function rowOrder() {
    return [...document.querySelectorAll(".upcoming-change-row")].map(
      (row) => row.dataset.upcomingChange
    );
  }

  test("sorts by most recent status change by default", async function (assert) {
    await visit("/admin/config/upcoming-changes");

    assert.dom(".upcoming-changes__sort-trigger").hasText("Recently updated");
    assert.deepEqual(rowOrder(), [
      "experimental_untracked",
      "alpha_recent",
      "stable_middle",
      "beta_old",
    ]);
  });

  test("sorts by status and name, keeping the choice in the URL", async function (assert) {
    await visit("/admin/config/upcoming-changes");

    await chooseSort("status");
    assert
      .dom(".upcoming-changes__sort-trigger")
      .hasAttribute("aria-label", "Sort by: Status");
    assert.strictEqual(
      currentURL(),
      "/admin/config/upcoming-changes?sort=status"
    );
    assert.deepEqual(rowOrder(), [
      "stable_middle",
      "beta_old",
      "alpha_recent",
      "experimental_untracked",
    ]);

    await chooseSort("name");
    assert.deepEqual(rowOrder(), [
      "alpha_recent",
      "beta_old",
      "experimental_untracked",
      "stable_middle",
    ]);

    await chooseSort("recently_updated");
    assert.strictEqual(currentURL(), "/admin/config/upcoming-changes");
  });

  test("keeps the sort when filters are reset", async function (assert) {
    await visit("/admin/config/upcoming-changes?sort=status&status=beta");

    assert.deepEqual(rowOrder(), ["beta_old"]);
    await click(".d-filter-controls__reset");

    assert.strictEqual(
      currentURL(),
      "/admin/config/upcoming-changes?sort=status"
    );
    assert.dom(".upcoming-changes__sort-trigger").hasText("Status");
    assert.strictEqual(rowOrder()[0], "stable_middle");
  });

  test("marks the current sort in the menu", async function (assert) {
    await visit("/admin/config/upcoming-changes?sort=name");
    await click(".upcoming-changes__sort-trigger");

    assert
      .dom(".upcoming-changes__sort-option[data-sort='name']")
      .hasAttribute("aria-current", "true");
    assert
      .dom(".upcoming-changes__sort-option[data-sort='status']")
      .doesNotHaveAttribute("aria-current");
  });

  test("falls back to the default for an unknown sort", async function (assert) {
    await visit("/admin/config/upcoming-changes?sort=bogus");

    assert.dom(".upcoming-changes__sort-trigger").hasText("Recently updated");
    assert.strictEqual(rowOrder()[0], "experimental_untracked");
  });

  test("falls back to the default for an inherited object property", async function (assert) {
    await visit("/admin/config/upcoming-changes?sort=constructor");

    assert.dom(".upcoming-changes__sort-trigger").hasText("Recently updated");
    assert.dom(".upcoming-change-row").exists({ count: 4 });
    assert.strictEqual(rowOrder()[0], "experimental_untracked");
  });
});
