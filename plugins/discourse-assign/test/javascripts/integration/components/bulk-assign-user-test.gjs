import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import BulkActionsAssignUser from "discourse/plugins/discourse-assign/discourse/components/bulk-actions/bulk-assign-user";

module("Integration | Component | BulkActionsAssignUser", function (hooks) {
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

  test("does not submit when no assignee has been chosen", async function (assert) {
    let registeredAction;
    let performed = false;
    const onRegisterAction = (callback) => (registeredAction = callback);
    const onPerform = () => (performed = true);

    await render(
      <template>
        <BulkActionsAssignUser
          @onRegisterAction={{onRegisterAction}}
          @onPerform={{onPerform}}
        />
      </template>
    );

    await registeredAction();
    await settled();

    assert.false(performed, "no bulk operation is sent");
    assert
      .dom(".assignee-error .error-label")
      .hasText(i18n("discourse_assign.assign_modal.choose_assignee"));
  });
});
