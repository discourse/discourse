import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import RequestGroupMembershipForm from "discourse/components/modal/request-group-membership-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | request-group-membership-form",
  function (hooks) {
    setupRenderingTest(hooks);

    test("correctly enables/disables the submit button", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const group = store.createRecord("group", {
        name: "a-team",
        membership_request_template: "plz accept thx",
      });
      const model = { group };

      await render(
        <template>
          <RequestGroupMembershipForm @model={{model}} @inline={{true}} />
        </template>
      );

      assert.dom("textarea").hasValue("plz accept thx");
      assert.dom(".btn-primary").isEnabled();

      await fillIn("textarea", "");
      assert.dom(".btn-primary").isDisabled();

      await fillIn("textarea", "hi there");
      assert.dom(".btn-primary").isEnabled();
      assert.dom("textarea").hasValue("hi there");

      // Doesn't modify the template
      assert.strictEqual(group.membership_request_template, "plz accept thx");

      pretender.post("/groups/a-team/request_membership.json", () => {
        assert.step("api");
        return response({});
      });

      await click(".btn-primary");
      assert.verifySteps(["api"]);
    });
  }
);
