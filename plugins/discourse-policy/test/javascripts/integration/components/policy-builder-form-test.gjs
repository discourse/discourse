import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import PolicyBuilderForm from "discourse/plugins/discourse-policy/discourse/components/policy-builder-form";

module(
  "Discourse Policy | Integration | Component | policy-builder-form",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.site = this.owner.lookup("service:site");
      this.site.groups = [
        AUTO_GROUPS.everyone,
        AUTO_GROUPS.admins,
        AUTO_GROUPS.moderators,
        AUTO_GROUPS.staff,
        AUTO_GROUPS.trust_level_0,
        { id: 100, name: "team" },
      ];

      this.set("data", { reminder: null, version: 1 });
      this.set("onRegisterApi", (api) => (this.formApi = api));
      this.set("onSubmit", (data) => (this.submittedData = data));
    });

    test("submits form data", async function (assert) {
      await render(
        <template>
          <PolicyBuilderForm
            @data={{this.data}}
            @onRegisterApi={{this.onRegisterApi}}
            @onSubmit={{this.onSubmit}}
          />
        </template>
      );

      const groupsChooser = selectKit(
        ".policy-builder-form__groups .group-chooser"
      );
      await groupsChooser.expand();
      await groupsChooser.selectRowByValue("admins");

      await fillIn("input[name='version']", "1");
      await fillIn("input[name='renew']", "1");
      await fillIn("input[name='renewStart']", "2022-06-07");

      const reminderChooser = selectKit(".combo-box");
      assert
        .dom(reminderChooser.header().el())
        .hasText(
          i18n("discourse_policy.builder.reminder.no_reminder"),
          "should be set by default"
        );

      await reminderChooser.expand();
      await reminderChooser.selectRowByValue("weekly");

      await fillIn("input[name='accept']", "foo");
      await fillIn("input[name='revoke']", "bar");

      const addGroupsChooser = selectKit(
        ".policy-builder-form__add-users-to-group .group-chooser"
      );
      await addGroupsChooser.expand();
      assert
        .dom(addGroupsChooser.rowByValue("moderators").el())
        .doesNotExist("automatic groups are not listed");
      await addGroupsChooser.selectRowByValue("team");

      await click("input[name='private']");
      await this.formApi.submit();

      assert.deepEqual(this.submittedData, {
        groups: "admins",
        version: 1,
        renew: 1,
        renewStart: "2022-06-07",
        reminder: "weekly",
        accept: "foo",
        revoke: "bar",
        addUsersToGroup: "team",
        private: true,
      });
    });

    test("does not submit invalid form data", async function (assert) {
      this.set("data", { version: 1 });
      this.set("onSubmit", () => (this.submitted = true));
      this.submitted = false;

      await render(
        <template>
          <PolicyBuilderForm
            @data={{this.data}}
            @onRegisterApi={{this.onRegisterApi}}
            @onSubmit={{this.onSubmit}}
          />
        </template>
      );

      await this.formApi.submit();

      assert.false(this.submitted, "onSubmit is not called");
    });
  }
);
