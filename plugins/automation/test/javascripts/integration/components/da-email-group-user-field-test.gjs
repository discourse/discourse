import { trackedObject } from "@ember/reactive/collections";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import DaEmailGroupUserField from "discourse/plugins/automation/admin/components/fields/da-email-group-user-field";

module("Integration | Component | EmailGroupUserField", function (hooks) {
  setupRenderingTest(hooks);

  test("Email group user field uses email-group-user-chooser component", async function (assert) {
    const template = <template>
      <DaEmailGroupUserField @label="a label" />
    </template>;

    await render(template);

    assert.dom(".control-label").hasText("a label");
    assert
      .dom(
        ".controls details.select-kit.multi-select.user-chooser.email-group-user-chooser"
      )
      .exists("has email-group-user-chooser");
  });

  test("with the new select controls, picks users, groups and addresses", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    let params;
    pretender.get("/u/search/users", (request) => {
      params = request.queryParams;
      return response({
        users: [{ username: "sam", avatar_template: "/a/{size}.png" }],
        groups: [{ name: "team", full_name: "The team" }],
      });
    });
    // Fields hold their value in a tracked object, as the model does.
    const field = { metadata: trackedObject({ value: undefined }) };

    await render(
      <template>
        <DaEmailGroupUserField @field={{field}} @label="a label" />
      </template>
    );
    const recipients = dSelect(".email-group-user-field .d-select");
    await recipients.search("te");
    await recipients.selectByName("team");
    await recipients.search("someone@example.com");
    await recipients.select("someone@example.com");

    assert.strictEqual(params.include_groups, "true");
    assert.deepEqual(field.metadata.value, ["team", "someone@example.com"]);
  });
});
