import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { tomorrow } from "discourse/lib/time-utils";
import Bookmark from "discourse/models/bookmark";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module("Integration | Component | bookmark-icon", function (hooks) {
  setupRenderingTest(hooks);

  test("with reminder", async function (assert) {
    this.setProperties({
      bookmark: Bookmark.create({
        reminder_at: tomorrow(this.currentUser.user_option.timezone),
        name: "some name",
        currentUser: this.currentUser,
      }),
    });

    await render(hbs`<BookmarkIcon @bookmark={{this.bookmark}} />`);

    assert.ok(
      exists(".d-icon-discourse-bookmark-clock.bookmark-icon__bookmarked")
    );
    assert.strictEqual(
      query(".svg-icon-title").title,
      I18n.t("bookmarks.created_with_reminder_generic", {
        date: formattedReminderTime(
          this.bookmark.reminder_at,
          this.currentUser.user_option.timezone
        ),
        name: "some name",
      })
    );
  });

  test("no reminder", async function (assert) {
    this.set(
      "bookmark",
      Bookmark.create({
        name: "some name",
        currentUser: this.currentUser,
      })
    );

    await render(hbs`<BookmarkIcon @bookmark={{this.bookmark}} />`);

    assert.dom(".d-icon-bookmark.bookmark-icon__bookmarked").exists();
    assert.strictEqual(
      query(".svg-icon-title").title,
      I18n.t("bookmarks.created_generic", {
        name: "some name",
      })
    );
  });

  test("null bookmark", async function (assert) {
    this.setProperties({
      bookmark: null,
    });

    await render(hbs`<BookmarkIcon @bookmark={{this.bookmark}} />`);

    assert.dom(".d-icon-bookmark.bookmark-icon").exists();
    assert.strictEqual(
      query(".svg-icon-title").title,
      I18n.t("bookmarks.create")
    );
  });
});
