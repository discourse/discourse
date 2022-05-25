import Bookmark from "discourse/models/bookmark";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";

discourseModule("Component | bookmark-icon", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("with reminder", {
    template: hbs`{{bookmark-icon bookmark=bookmark}}`,

    beforeEach() {
      this.set(
        "bookmark",
        Bookmark.create({
          reminder_at: moment(),
          name: "some name",
        })
      );
    },

    async test(assert) {
      assert.ok(exists(".d-icon-discourse-bookmark-clock"));
    },
  });

  componentTest("no reminder", {
    template: hbs`{{bookmark-icon bookmark=bookmark}}`,

    beforeEach() {
      this.set(
        "bookmark",
        Bookmark.create({
          name: "some name",
        })
      );
    },

    async test(assert) {
      assert.ok(exists(".d-icon-bookmark"));
    },
  });
});
