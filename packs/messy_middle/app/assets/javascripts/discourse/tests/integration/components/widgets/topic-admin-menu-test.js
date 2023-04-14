import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import Category from "discourse/models/category";
import { getOwner } from "discourse-common/lib/get-owner";

const createArgs = (topic) => {
  return {
    topic,
    openUpwards: "true",
    toggleMultiSelect: () => {},
    deleteTopic: () => {},
    recoverTopic: () => {},
    toggleClosed: () => {},
    toggleArchived: () => {},
    toggleVisibility: () => {},
    showTopicTimerModal: () => {},
    showFeatureTopic: () => {},
    showChangeTimestamp: () => {},
    resetBumpDate: () => {},
    convertToPublicTopic: () => {},
    convertToPrivateMessage: () => {},
  };
};

module(
  "Integration | Component | Widget | topic-admin-menu-button",
  function (hooks) {
    setupRenderingTest(hooks);

    test("topic-admin-menu-button is present for admin/moderators", async function (assert) {
      this.currentUser.setProperties({
        admin: true,
        moderator: true,
        id: 123,
      });

      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        user_id: this.currentUser.id,
      });
      topic.set("category_id", Category.create({ read_restricted: true }).id);

      this.siteSettings.allow_featured_topic_on_user_profiles = true;
      this.set("args", createArgs(topic));

      await render(
        hbs`<MountWidget @widget="topic-admin-menu-button" @args={{this.args}} />`
      );

      assert.ok(exists(".toggle-admin-menu"), "admin wrench is present");
    });

    test("topic-admin-menu-button hides for non-admin when there is no action", async function (assert) {
      this.currentUser.setProperties({
        admin: false,
        moderator: false,
        id: 123,
      });

      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        user_id: this.currentUser.id,
      });
      topic.set("category_id", Category.create({ read_restricted: true }).id);

      this.siteSettings.allow_featured_topic_on_user_profiles = true;
      this.set("args", createArgs(topic));

      await render(
        hbs`<MountWidget @widget="topic-admin-menu-button" @args={{this.args}} />`
      );

      assert.ok(!exists(".toggle-admin-menu"), "admin wrench is not present");
    });
  }
);
