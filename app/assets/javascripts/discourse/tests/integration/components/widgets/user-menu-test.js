import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists, query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";

module("Integration | Component | Widget | user-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("basics", async function (assert) {
    await render(hbs`<MountWidget @widget="user-menu" />`);

    assert.ok(exists(".user-menu"));
    assert.ok(exists(".user-preferences-link"));
    assert.ok(exists(".user-notifications-link"));
    assert.ok(exists(".user-bookmarks-link"));
    assert.ok(exists(".quick-access-panel"));
    assert.ok(exists(".notifications-dismiss"));
  });

  test("notifications", async function (assert) {
    await render(hbs`<MountWidget @widget="user-menu" />`);

    const links = queryAll(".quick-access-panel li a");

    assert.strictEqual(links.length, 6);
    assert.ok(links[1].href.includes("/t/a-slug/123"));

    assert.ok(
      links[2].href.includes(
        "/u/eviltrout/notifications/likes-received?acting_username=aquaman"
      )
    );

    assert.strictEqual(
      links[2].text,
      `aquaman ${I18n.t("notifications.liked_consolidated_description", {
        count: 5,
      })}`
    );

    assert.ok(links[3].href.includes("/u/test2/messages/group/test"));
    assert.ok(
      links[3].innerHTML.includes(
        I18n.t("notifications.group_message_summary", {
          count: 5,
          group_name: "test",
        })
      )
    );

    assert.ok(links[4].href.includes("/u/test1"));
    assert.ok(
      links[4].innerHTML.includes(
        I18n.t("notifications.invitee_accepted", { username: "test1" })
      )
    );

    assert.ok(links[5].href.includes("/g/test"));
    assert.ok(
      links[5].innerHTML.includes(
        I18n.t("notifications.membership_request_accepted", {
          group_name: "test",
        })
      )
    );

    const routeToStub = sinon.stub(DiscourseURL, "routeTo");
    await click(".user-notifications-link");
    assert.ok(
      routeToStub.calledWith(query(".user-notifications-link").dataset.url),
      "a second click should redirect to the full notifications page"
    );
  });

  test("log out", async function (assert) {
    this.set("logout", () => (this.loggedOut = true));

    await render(
      hbs`<MountWidget @widget="user-menu" @logout={{this.logout}} />`
    );

    await click(".user-preferences-link");

    assert.ok(exists(".logout"));

    await click(".logout button");
    assert.ok(this.loggedOut);
  });

  test("private messages - disabled", async function (assert) {
    this.currentUser.setProperties({
      admin: false,
      moderator: false,
      can_send_private_messages: false,
    });

    await render(hbs`<MountWidget @widget="user-menu" />`);

    assert.ok(!exists(".user-pms-link"));
  });

  test("private messages - enabled", async function (assert) {
    this.currentUser.setProperties({
      admin: false,
      moderator: false,
      can_send_private_messages: true,
    });

    await render(hbs`<MountWidget @widget="user-menu" />`);

    const userPmsLink = query(".user-pms-link").dataset.url;
    assert.ok(userPmsLink);
    await click(".user-pms-link");

    const message = query(".quick-access-panel li a");
    assert.ok(message);

    assert.ok(
      message.href.includes("/t/bug-can-not-render-emoji-properly/174/2"),
      "should link to the next unread post"
    );
    assert.ok(
      message.innerHTML.includes("mixtape"),
      "should include the last poster's username"
    );
    assert.ok(
      message.innerHTML.match(/<img.*class="emoji".*>/),
      "should correctly render emoji in message title"
    );

    const routeToStub = sinon.stub(DiscourseURL, "routeTo");
    await click(".user-pms-link");
    assert.ok(
      routeToStub.calledWith(userPmsLink),
      "a second click should redirect to the full private messages page"
    );
  });

  test("bookmarks", async function (assert) {
    await render(hbs`<MountWidget @widget="user-menu" />`);

    await click(".user-bookmarks-link");

    const allBookmarks = queryAll(".quick-access-panel li a");
    const bookmark = allBookmarks[0];

    assert.ok(
      bookmark.href.includes("/t/yelling-topic-title/119"),
      "the Post bookmark should have a link to the topic"
    );
    assert.ok(
      bookmark.innerHTML.includes("someguy"),
      "should include the last poster's username"
    );
    assert.ok(
      bookmark.innerHTML.match(/<img.*class="emoji".*>/),
      "should correctly render emoji in bookmark title"
    );
    assert.ok(
      bookmark.innerHTML.includes("d-icon-bookmark"),
      "should use the correct icon based on no reminder_at present"
    );

    const routeToStub = sinon.stub(DiscourseURL, "routeTo");
    await click(".user-bookmarks-link");
    assert.ok(
      routeToStub.calledWith(query(".user-bookmarks-link").dataset.url),
      "a second click should redirect to the full bookmarks page"
    );

    const nonPostBookmarkableBookmark = allBookmarks[1];
    assert.ok(
      nonPostBookmarkableBookmark.href.includes("chat/message/2437"),
      "bookmarkable_type that is not Post or Topic should use bookmarkable_url for the item link"
    );
    assert.ok(
      nonPostBookmarkableBookmark.innerHTML.includes(
        "d-icon-discourse-bookmark-clock"
      ),
      "should use the correct icon based on reminder_at present"
    );
  });

  test("anonymous", async function (assert) {
    this.currentUser.setProperties({ is_anonymous: false, trust_level: 3 });
    this.siteSettings.allow_anonymous_posting = true;
    this.siteSettings.anonymous_posting_min_trust_level = 3;
    this.set("toggleAnonymous", () => (this.anonymous = true));

    await render(hbs`
        <MountWidget @widget="user-menu" @toggleAnonymous={{this.toggleAnonymous}} />
      `);

    await click(".user-preferences-link");
    assert.ok(exists(".enable-anonymous"));

    await click(".enable-anonymous");
    assert.ok(this.anonymous);
  });

  test("anonymous - disabled", async function (assert) {
    this.siteSettings.allow_anonymous_posting = false;

    await render(hbs`<MountWidget @widget="user-menu" />`);

    await click(".user-preferences-link");
    assert.ok(!exists(".enable-anonymous"));
  });

  test("anonymous - switch back", async function (assert) {
    this.currentUser.setProperties({ is_anonymous: true });
    this.siteSettings.allow_anonymous_posting = true;
    this.set("toggleAnonymous", () => (this.anonymous = false));

    await render(hbs`
        <MountWidget @widget="user-menu" @toggleAnonymous={{this.toggleAnonymous}} />
      `);

    await click(".user-preferences-link");
    assert.ok(exists(".disable-anonymous"));

    await click(".disable-anonymous");
    assert.notOk(this.anonymous);
  });
});
