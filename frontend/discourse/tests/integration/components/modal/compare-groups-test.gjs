import { array, hash } from "@ember/helper";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CompareGroups from "discourse/admin/components/modal/compare-groups";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Modal | compare-groups", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "admins" },
      { id: 2, name: "moderators" },
      { id: 3, name: "staff" },
      { id: 4, name: "anonymous_users" },
      { id: 5, name: "logged_in_users" },
      { id: 10, name: "support", full_name: "Support" },
      { id: 11, name: "beta_testers", full_name: "Beta testers" },
    ];
  });

  const noop = () => {};

  test("pre-selects the given current tokens", async function (assert) {
    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash
            currentTokens=(array "new_members" "returning" "staff")
          }}
        />
      </template>
    );

    assert
      .dom(".manageable-row-list__counter")
      .hasText("3 of 10 groups selected");
    assert
      .dom("[data-identifier='new_members'].manageable-row-list__row.--enabled")
      .exists();
    assert
      .dom("[data-identifier='returning'].manageable-row-list__row.--enabled")
      .exists();
    assert
      .dom("[data-identifier='staff'].manageable-row-list__row.--enabled")
      .exists();
  });

  test("excludes the everyone/anonymous/logged-in pseudogroups and the real staff auto-group", async function (assert) {
    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash currentTokens=(array "staff")}}
        />
      </template>
    );

    assert.dom("[data-identifier='group:0']").doesNotExist();
    assert.dom("[data-identifier='group:3']").doesNotExist();
    assert.dom("[data-identifier='group:4']").doesNotExist();
    assert.dom("[data-identifier='group:5']").doesNotExist();
    assert.dom("[data-identifier='group:1']").exists();
    assert.dom("[data-identifier='group:10']").exists();
  });

  test("search filters the disabled rows by title", async function (assert) {
    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash currentTokens=(array "staff")}}
        />
      </template>
    );

    await fillIn(".compare-groups input", "support");

    assert.dom("[data-identifier='group:10']").exists();
    assert.dom("[data-identifier='group:11']").doesNotExist();
    assert.dom("[data-identifier='staff']").exists();
  });

  test("toggling a row on adds it to the selection, and off removes it", async function (assert) {
    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash currentTokens=(array "staff")}}
        />
      </template>
    );

    await click("[data-identifier='group:10'] .d-toggle-switch__checkbox");
    assert
      .dom(".manageable-row-list__counter")
      .hasText("2 of 10 groups selected");

    await click("[data-identifier='staff'] .d-toggle-switch__checkbox");
    assert
      .dom(".manageable-row-list__counter")
      .hasText("1 of 10 groups selected");
  });

  test("prevents disabling the last remaining selected row", async function (assert) {
    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash currentTokens=(array "staff")}}
        />
      </template>
    );

    assert
      .dom("[data-identifier='staff'] .d-toggle-switch__checkbox")
      .isDisabled();
    assert
      .dom(".manageable-row-list__counter")
      .hasText("1 of 10 groups selected");
    assert
      .dom("[data-identifier='staff'].manageable-row-list__row.--enabled")
      .exists();
  });

  test("disables further toggles once the cap of 10 is reached", async function (assert) {
    this.site.groups = Array.from({ length: 12 }, (_, i) => ({
      id: 100 + i,
      name: `group-${i}`,
    }));

    await render(
      <template>
        <CompareGroups
          @closeModal={{noop}}
          @inline={{true}}
          @model={{hash
            currentTokens=(array
              "group:100"
              "group:101"
              "group:102"
              "group:103"
              "group:104"
              "group:105"
              "group:106"
              "group:107"
              "group:108"
              "group:109"
            )
          }}
        />
      </template>
    );

    assert
      .dom(".manageable-row-list__counter")
      .hasText("10 of 10 groups selected");
    assert
      .dom("[data-identifier='group:110'] .d-toggle-switch__checkbox")
      .isDisabled();
  });

  test("apply calls onApply with the ordered selection and closes the modal", async function (assert) {
    let appliedTokens;
    let closed = false;

    const onApply = (tokens) => (appliedTokens = tokens);
    const closeModal = () => (closed = true);

    await render(
      <template>
        <CompareGroups
          @closeModal={{closeModal}}
          @inline={{true}}
          @model={{hash currentTokens=(array "staff") onApply=onApply}}
        />
      </template>
    );

    await click("[data-identifier='group:10'] .d-toggle-switch__checkbox");
    await click(".compare-groups__apply");

    assert.deepEqual(appliedTokens, ["staff", "group:10"]);
    assert.true(closed);
  });
});
