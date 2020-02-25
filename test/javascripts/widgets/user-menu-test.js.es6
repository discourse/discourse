import DiscourseURL from "discourse/lib/url";
import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("user-menu");

widgetTest("basics", {
  template: '{{mount-widget widget="user-menu"}}',

  test(assert) {
    assert.ok(find(".user-menu").length);
    assert.ok(find(".user-activity-link").length);
    assert.ok(find(".user-notifications-link").length);
    assert.ok(find(".user-bookmarks-link").length);
    assert.ok(find(".quick-access-panel").length);
    assert.ok(find(".dismiss-link").length);
  }
});

widgetTest("notifications", {
  template: '{{mount-widget widget="user-menu"}}',

  async test(assert) {
    const $links = find(".quick-access-panel li a");

    assert.equal($links.length, 5);
    assert.ok($links[0].href.includes("/t/a-slug/123"));

    assert.ok(
      $links[1].href.includes(
        "/u/eviltrout/notifications/likes-received?acting_username=aquaman"
      )
    );

    assert.equal(
      $links[1].text,
      `aquaman ${I18n.t("notifications.liked_consolidated_description", {
        count: 5
      })}`
    );

    assert.ok($links[2].href.includes("/u/test2/messages/group/test"));
    assert.ok(
      $links[2].innerHTML.includes(
        I18n.t("notifications.group_message_summary", {
          count: 5,
          group_name: "test"
        })
      )
    );

    assert.ok($links[3].href.includes("/u/test1"));
    assert.ok(
      $links[3].innerHTML.includes(
        I18n.t("notifications.invitee_accepted", { username: "test1" })
      )
    );

    assert.ok($links[4].href.includes("/g/test"));
    assert.ok(
      $links[4].innerHTML.includes(
        I18n.t("notifications.membership_request_accepted", {
          group_name: "test"
        })
      )
    );

    const routeToStub = sandbox.stub(DiscourseURL, "routeTo");
    await click(".user-notifications-link");
    assert.ok(
      routeToStub.calledWith(find(".user-notifications-link")[0].href),
      "a second click should redirect to the full notifications page"
    );
  }
});

widgetTest("log out", {
  template: '{{mount-widget widget="user-menu" logout=(action "logout")}}',

  beforeEach() {
    this.on("logout", () => (this.loggedOut = true));
  },

  async test(assert) {
    await click(".user-activity-link");
    assert.ok(find(".logout").length);

    await click(".logout");
    assert.ok(this.loggedOut);
  }
});

widgetTest("private messages - disabled", {
  template: '{{mount-widget widget="user-menu"}}',
  beforeEach() {
    this.siteSettings.enable_personal_messages = false;
  },

  test(assert) {
    assert.ok(!find(".user-pms-link").length);
  }
});

widgetTest("private messages - enabled", {
  template: '{{mount-widget widget="user-menu"}}',
  beforeEach() {
    this.siteSettings.enable_personal_messages = true;
  },

  async test(assert) {
    const userPmsLink = find(".user-pms-link")[0];
    assert.ok(userPmsLink);
    await click(".user-pms-link");

    const message = find(".quick-access-panel li a")[0];
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

    const routeToStub = sandbox.stub(DiscourseURL, "routeTo");
    await click(".user-pms-link");
    assert.ok(
      routeToStub.calledWith(userPmsLink.href),
      "a second click should redirect to the full private messages page"
    );
  }
});

widgetTest("bookmarks", {
  template: '{{mount-widget widget="user-menu"}}',

  async test(assert) {
    await click(".user-bookmarks-link");

    const bookmark = find(".quick-access-panel li a")[0];
    assert.ok(bookmark);

    assert.ok(
      bookmark.href.includes("/t/how-to-check-the-user-level-via-ajax/11993")
    );
    assert.ok(
      bookmark.innerHTML.includes("Abhishek_Gupta"),
      "should include the last poster's username"
    );
    assert.ok(
      bookmark.innerHTML.match(/<img.*class="emoji".*>/),
      "should correctly render emoji in bookmark title"
    );

    const routeToStub = sandbox.stub(DiscourseURL, "routeTo");
    await click(".user-bookmarks-link");
    assert.ok(
      routeToStub.calledWith(find(".user-bookmarks-link")[0].href),
      "a second click should redirect to the full bookmarks page"
    );
  }
});

widgetTest("anonymous", {
  template:
    '{{mount-widget widget="user-menu" toggleAnonymous=(action "toggleAnonymous")}}',

  beforeEach() {
    this.currentUser.setProperties({ is_anonymous: false, trust_level: 3 });
    this.siteSettings.allow_anonymous_posting = true;
    this.siteSettings.anonymous_posting_min_trust_level = 3;

    this.on("toggleAnonymous", () => (this.anonymous = true));
  },

  async test(assert) {
    await click(".user-activity-link");
    assert.ok(find(".enable-anonymous").length);

    await click(".enable-anonymous");
    assert.ok(this.anonymous);
  }
});

widgetTest("anonymous - disabled", {
  template: '{{mount-widget widget="user-menu"}}',

  beforeEach() {
    this.siteSettings.allow_anonymous_posting = false;
  },

  async test(assert) {
    await click(".user-activity-link");
    assert.ok(!find(".enable-anonymous").length);
  }
});

widgetTest("anonymous - switch back", {
  template:
    '{{mount-widget widget="user-menu" toggleAnonymous=(action "toggleAnonymous")}}',

  beforeEach() {
    this.currentUser.setProperties({ is_anonymous: true });
    this.siteSettings.allow_anonymous_posting = true;

    this.on("toggleAnonymous", () => (this.anonymous = false));
  },

  async test(assert) {
    await click(".user-activity-link");
    assert.ok(find(".disable-anonymous").length);

    await click(".disable-anonymous");
    assert.notOk(this.anonymous);
  }
});
