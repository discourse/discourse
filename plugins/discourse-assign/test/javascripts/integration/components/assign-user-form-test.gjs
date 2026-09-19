import { trackedObject } from "@ember/reactive/collections";
import { focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import AssignUserForm from "discourse/plugins/discourse-assign/discourse/components/assign-user-form";

module("Integration | Component | AssignUserForm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/assign/suggestions", () =>
      response({
        suggestions: [],
        assign_allowed_on_groups: [],
        assign_allowed_for_groups: [],
      })
    );
  });

  for (const modifier of ["metaKey", "ctrlKey"]) {
    test(`${modifier}+Enter submits from the assignee picker and note`, async function (assert) {
      const model = trackedObject({
        username: "eviltrout",
        targetType: "Post",
      });
      const formApi = {};
      let submissions = 0;
      const onSubmit = () => submissions++;

      await render(
        <template>
          <AssignUserForm
            @formApi={{formApi}}
            @model={{model}}
            @onSubmit={{onSubmit}}
          />
        </template>
      );

      await focus("#assignee-chooser-header");
      await triggerKeyEvent("#assignee-chooser-header", "keydown", "Enter", {
        [modifier]: true,
      });
      assert.strictEqual(
        submissions,
        1,
        "submits once from the assignee picker"
      );

      await focus("#assign-modal-note");
      await triggerKeyEvent("#assign-modal-note", "keydown", "Enter");
      assert.strictEqual(
        submissions,
        1,
        "plain Enter in the note does not submit"
      );

      await triggerKeyEvent("#assign-modal-note", "keydown", "Enter", {
        [modifier]: true,
      });
      assert.strictEqual(submissions, 2, "submits once from the note");
    });

    test(`${modifier}+Enter requires an assignee`, async function (assert) {
      const model = trackedObject({ targetType: "Post" });
      const formApi = {};
      let submitted = false;
      const onSubmit = () => (submitted = true);

      await render(
        <template>
          <AssignUserForm
            @formApi={{formApi}}
            @model={{model}}
            @onSubmit={{onSubmit}}
          />
        </template>
      );

      await triggerKeyEvent(
        "#assignee-chooser .filter-input",
        "keydown",
        "Enter",
        {
          [modifier]: true,
        }
      );

      assert.false(submitted, "does not submit without an assignee");
      assert
        .dom(".assignee-error .error-label")
        .hasText(
          i18n("discourse_assign.assign_modal.choose_assignee"),
          "shows the assignee validation error"
        );
    });
  }
});
