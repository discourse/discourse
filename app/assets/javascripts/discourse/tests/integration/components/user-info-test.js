import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";

discourseModule("Integration | Component | user-info", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("prioritized name", {
    template: hbs`{{user-info user=currentUser}}`,

    beforeEach() {
      this.siteSettings.prioritize_username_in_ux = false;
      this.currentUser.name = "Evil Trout";
    },

    async test(assert) {
      assert.equal(query(".name.bold").innerText.trim(), "Evil Trout");
      assert.equal(query(".username.margin").innerText.trim(), "eviltrout");
    },
  });

  componentTest("prioritized username", {
    template: hbs`{{user-info user=currentUser}}`,

    beforeEach() {
      this.siteSettings.prioritize_username_in_ux = true;
      this.currentUser.name = "Evil Trout";
    },

    async test(assert) {
      assert.equal(query(".username.bold").innerText.trim(), "eviltrout");
      assert.equal(query(".name.margin").innerText.trim(), "Evil Trout");
    },
  });

  componentTest("includeLink", {
    template: hbs`{{user-info user=currentUser includeLink=includeLink}}`,

    async test(assert) {
      this.set("includeLink", true);

      assert.ok(exists(`.username a[href="/u/${this.currentUser.username}"]`));

      this.set("includeLink", false);

      assert.notOk(
        exists(`.username a[href="/u/${this.currentUser.username}"]`)
      );
    },
  });

  componentTest("includeAvatar", {
    template: hbs`{{user-info user=currentUser includeAvatar=includeAvatar}}`,

    async test(assert) {
      this.set("includeAvatar", true);

      assert.ok(exists(".user-image"));

      this.set("includeAvatar", false);

      assert.notOk(exists(".user-image"));
    },
  });
});
