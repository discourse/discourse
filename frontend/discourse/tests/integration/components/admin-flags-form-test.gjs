import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AdminFlagsForm from "discourse/admin/components/admin-flags-form";
import PostActionType from "discourse/models/post-action-type";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | AdminFlagsForm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.site = this.owner.lookup("service:site");
    this.site.set("valid_flag_applies_to_types", ["Post"]);
    this.site.set("post_action_types", [
      PostActionType.create({
        id: 3,
        name: "Off-Topic",
        name_key: "off_topic",
        is_flag: true,
        system: true,
      }),
    ]);
    sinon.stub(this.owner.lookup("service:router"), "transitionTo");
  });

  test("a created flag joins the site's flag types as a post action type", async function (assert) {
    pretender.post("/admin/config/flags", () =>
      response(200, {
        flag: {
          id: 2001,
          name: "Custom flag",
          name_key: "custom_custom_flag",
          description: "A custom flag",
          short_description: "",
          applies_to: ["Post"],
          position: 2,
          require_message: false,
          enabled: true,
          is_flag: true,
          is_used: false,
          auto_action_type: false,
          system: false,
        },
      })
    );

    await render(<template><AdminFlagsForm /></template>);

    await form().field("name").fillIn("Custom flag");
    await form().field("description").fillIn("A custom flag");
    await form().field("appliesTo").select("Post");
    await form().submit();

    const created = this.site.flagTypes.find((flag) => flag.id === 2001);
    assert.strictEqual(created?.name, "Custom flag", "the new flag is listed");
    assert.true(
      created instanceof PostActionType,
      "the new flag is a post action type, like the flags the site loaded"
    );
    assert.false(created.isIllegal);
  });
});
