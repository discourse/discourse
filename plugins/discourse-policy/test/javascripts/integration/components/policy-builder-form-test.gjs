import EmberObject from "@ember/object";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import PolicyBuilderForm from "discourse/plugins/discourse-policy/discourse/components/policy-builder-form";

module(
  "Discourse Policy | Integration | Component | policy-builder-form",
  function (hooks) {
    setupRenderingTest(hooks);

    test("onChange", async function (assert) {
      const self = this;

      this.set("policy", new EmberObject());
      this.set("onChange", (key, value) => {
        query(".output").innerText = `${key}=${value}`;
      });

      await render(
        <template>
          <span class="output"></span>
          <PolicyBuilderForm
            @onChange={{self.onChange}}
            @policy={{self.policy}}
          />
        </template>
      );

      const groupsChooser = selectKit(".groups .group-chooser");
      await groupsChooser.expand();
      await groupsChooser.selectRowByValue("admins");
      assert.dom(".output").hasText("groups=admins");

      await fillIn("input[name='version']", "1");
      assert.dom(".output").hasText("version=1");

      await fillIn("input[name='renew']", "1");
      assert.dom(".output").hasText("renew=1");

      await fillIn("input[name='renew-start']", "2022-06-07");
      assert.dom(".output").hasText("renew-start=2022-06-07");

      const reminderChooser = selectKit(".combo-box");
      assert
        .dom(reminderChooser.header().el())
        .hasText(
          i18n("discourse_policy.builder.reminder.no_reminder"),
          "should be set by default"
        );

      await reminderChooser.expand();
      await reminderChooser.selectRowByValue("weekly");
      assert.dom(".output").hasText("reminder=weekly");

      await fillIn("input[name='accept']", "foo");
      assert.dom(".output").hasText("accept=foo");

      await fillIn("input[name='revoke']", "bar");
      assert.dom(".output").hasText("revoke=bar");

      const addGroupsChooser = selectKit(".add-users-to-group .group-chooser");
      await addGroupsChooser.expand();
      await addGroupsChooser.selectRowByValue("moderators");
      assert.dom(".output").hasText("add-users-to-group=moderators");

      await click("input[name='private']");
      assert.dom(".output").hasText("private=true");
    });
  }
);
