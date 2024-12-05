import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BookmarkIcon from "discourse/components/bookmark-icon";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { tomorrow } from "discourse/lib/time-utils";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | bookmark-icon", function (hooks) {
  setupRenderingTest(hooks);

  test("with reminder", async function (assert) {
    const store = this.owner.lookup("service:store");
    const bookmark = store.createRecord("bookmark", {
      reminder_at: tomorrow(this.currentUser.user_option.timezone),
      name: "some name",
      currentUser: this.currentUser,
    });

    await render(<template><BookmarkIcon @bookmark={{bookmark}} /></template>);

    assert
      .dom(".d-icon-discourse-bookmark-clock.bookmark-icon__bookmarked")
      .exists();
    assert.dom(".svg-icon-title").hasAttribute(
      "title",
      i18n("bookmarks.created_with_reminder_generic", {
        date: formattedReminderTime(
          bookmark.reminder_at,
          this.currentUser.user_option.timezone
        ),
        name: "some name",
      })
    );
  });

  test("no reminder", async function (assert) {
    const store = this.owner.lookup("service:store");
    const bookmark = store.createRecord("bookmark", {
      name: "some name",
      currentUser: this.currentUser,
    });

    await render(<template><BookmarkIcon @bookmark={{bookmark}} /></template>);

    assert.dom(".d-icon-bookmark.bookmark-icon__bookmarked").exists();
    assert.dom(".svg-icon-title").hasAttribute(
      "title",
      i18n("bookmarks.created_generic", {
        name: "some name",
      })
    );
  });

  test("no bookmark", async function (assert) {
    await render(<template><BookmarkIcon /></template>);

    assert.dom(".d-icon-bookmark.bookmark-icon").exists();
    assert
      .dom(".svg-icon-title")
      .hasAttribute("title", i18n("bookmarks.create"));
  });
});
