import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import sinon from "sinon";

discourseModule(
  "Integration | Component | Widget | user-menu",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("basics", {
      template: hbs`{{mount-widget widget="user-menu"}}`,

      test(assert) {
        assert.ok(queryAll(".user-menu").length);
        assert.ok(queryAll(".user-preferences-link").length);
        assert.ok(queryAll(".user-notifications-link").length);
        assert.ok(queryAll(".user-bookmarks-link").length);
        assert.ok(queryAll(".quick-access-panel").length);
        assert.ok(queryAll(".notifications-dismiss").length);
      },
    });

    componentTest("notifications", {
      template: hbs`{{mount-widget widget="user-menu"}}`,

      async test(assert) {
        const $links = queryAll(".quick-access-panel li a");

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
            count: 5,
          })}`
        );

        assert.ok($links[2].href.includes("/u/test2/messages/group/test"));
        assert.ok(
          $links[2].innerHTML.includes(
            I18n.t("notifications.group_message_summary", {
              count: 5,
              group_name: "test",
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
              group_name: "test",
            })
          )
        );

        const routeToStub = sinon.stub(DiscourseURL, "routeTo");
        await click(".user-notifications-link");
        assert.ok(
          routeToStub.calledWith(
            queryAll(".user-notifications-link").data("url")
          ),
          "a second click should redirect to the full notifications page"
        );
      },
    });

    componentTest("log out", {
      template: hbs`{{mount-widget widget="user-menu" logout=logout}}`,

      beforeEach() {
        this.set("logout", () => (this.loggedOut = true));
      },

      async test(assert) {
        await click(".user-preferences-link");

        assert.ok(queryAll(".logout").length);

        await click(".logout button");
        assert.ok(this.loggedOut);
      },
    });

    componentTest("private messages - disabled", {
      template: hbs`{{mount-widget widget="user-menu"}}`,
      beforeEach() {
        this.siteSettings.enable_personal_messages = false;
      },

      test(assert) {
        assert.ok(!queryAll(".user-pms-link").length);
      },
    });

    componentTest("private messages - enabled", {
      template: hbs`{{mount-widget widget="user-menu"}}`,
      beforeEach() {
        this.siteSettings.enable_personal_messages = true;
      },

      async test(assert) {
        const userPmsLink = queryAll(".user-pms-link").data("url");
        assert.ok(userPmsLink);
        await click(".user-pms-link");

        const message = queryAll(".quick-access-panel li a")[0];
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
      },
    });

    componentTest("bookmarks", {
      template: hbs`{{mount-widget widget="user-menu"}}`,

      async test(assert) {
        await click(".user-bookmarks-link");

        const bookmark = queryAll(".quick-access-panel li a")[0];
        assert.ok(bookmark);

        assert.ok(bookmark.href.includes("/t/yelling-topic-title/119"));
        assert.ok(
          bookmark.innerHTML.includes("someguy"),
          "should include the last poster's username"
        );
        assert.ok(
          bookmark.innerHTML.match(/<img.*class="emoji".*>/),
          "should correctly render emoji in bookmark title"
        );

        const routeToStub = sinon.stub(DiscourseURL, "routeTo");
        await click(".user-bookmarks-link");
        assert.ok(
          routeToStub.calledWith(queryAll(".user-bookmarks-link").data("url")),
          "a second click should redirect to the full bookmarks page"
        );
      },
    });

    componentTest("anonymous", {
      template: hbs`
      {{mount-widget widget="user-menu" toggleAnonymous=toggleAnonymous}}
    `,

      beforeEach() {
        this.currentUser.setProperties({ is_anonymous: false, trust_level: 3 });
        this.siteSettings.allow_anonymous_posting = true;
        this.siteSettings.anonymous_posting_min_trust_level = 3;

        this.set("toggleAnonymous", () => (this.anonymous = true));
      },

      async test(assert) {
        await click(".user-preferences-link");
        assert.ok(queryAll(".enable-anonymous").length);

        await click(".enable-anonymous");
        assert.ok(this.anonymous);
      },
    });

    componentTest("anonymous - disabled", {
      template: hbs`{{mount-widget widget="user-menu"}}`,

      beforeEach() {
        this.siteSettings.allow_anonymous_posting = false;
      },

      async test(assert) {
        await click(".user-preferences-link");
        assert.ok(!queryAll(".enable-anonymous").length);
      },
    });

    componentTest("anonymous - switch back", {
      template: hbs`
      {{mount-widget widget="user-menu" toggleAnonymous=toggleAnonymous}}
    `,

      beforeEach() {
        this.currentUser.setProperties({ is_anonymous: true });
        this.siteSettings.allow_anonymous_posting = true;

        this.set("toggleAnonymous", () => (this.anonymous = false));
      },

      async test(assert) {
        await click(".user-preferences-link");
        assert.ok(queryAll(".disable-anonymous").length);

        await click(".disable-anonymous");
        assert.notOk(this.anonymous);
      },
    });
  }
);
