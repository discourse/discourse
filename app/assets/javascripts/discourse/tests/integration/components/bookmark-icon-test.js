import Bookmark from "discourse/models/bookmark";
import I18n from "I18n";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { tomorrow } from "discourse/lib/time-utils";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";

discourseModule("Component | bookmark-icon", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("with reminder", {
    template: hbs`{{bookmark-icon bookmark=bookmark}}`,

    beforeEach() {
      this.currentUser.set("timezone", "Australia/Brisbane");
      this.setProperties({
        bookmark: Bookmark.create({
          reminder_at: tomorrow(this.currentUser.timezone),
          name: "some name",
        }),
      });
    },

    async test(assert) {
      assert.ok(exists(".d-icon-discourse-bookmark-clock"));
      assert.strictEqual(
        query(".svg-icon-title")["title"],
        I18n.t("bookmarks.created_with_reminder_generic", {
          date: formattedReminderTime(
            this.bookmark.reminder_at,
            this.currentUser.timezone
          ),
          name: "some name",
        })
      );
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
      assert.strictEqual(
        query(".svg-icon-title")["title"],
        I18n.t("bookmarks.created_generic", {
          name: "some name",
        })
      );
    },
  });
});
