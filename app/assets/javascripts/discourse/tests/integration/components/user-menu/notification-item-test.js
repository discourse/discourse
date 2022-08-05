import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { click, render, settled } from "@ember/test-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import Notification from "discourse/models/notification";
import { hbs } from "ember-cli-htmlbars";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.mentioned,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          display_username: "osama",
          original_post_id: 1,
          original_post_type: 1,
          original_username: "velesin",
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::NotificationItem @item={{this.notification}}/>`;

    test("pushes `read` to the classList if the notification is read", async function (assert) {
      this.set("notification", getNotification());
      this.notification.read = false;
      await render(template);
      assert.ok(!exists("li.read"));
      assert.ok(exists("li"));

      this.notification.read = true;
      await settled();

      assert.ok(
        exists("li.read"),
        "the item re-renders when the read property is updated"
      );
    });

    test("pushes the notification type name to the classList", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      let item = query("li");
      assert.strictEqual(item.className, "mentioned");

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.private_message,
        })
      );
      await settled();

      assert.ok(
        exists("li.private-message"),
        "replaces underscores in type name with dashes"
      );
    });

    test("pushes is-warning to the classList if the notification originates from a warning PM", async function (assert) {
      this.set("notification", getNotification({ is_warning: true }));
      await render(template);
      assert.ok(exists("li.is-warning"));
    });

    test("doesn't push is-warning to the classList if the notification doesn't originate from a warning PM", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      assert.ok(!exists("li.is-warning"));
      assert.ok(exists("li"));
    });

    test("the item's href links to the topic that the notification originates from", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.ok(link.href.endsWith("/t/this-is-fancy-title/449/113"));
    });

    test("the item's href links to the group messages if the notification is for a group messages", async function (assert) {
      this.set(
        "notification",
        getNotification({
          topic_id: null,
          post_number: null,
          slug: null,
          data: {
            group_id: 33,
            group_name: "grouperss",
            username: "ossaama",
          },
        })
      );
      await render(template);
      const link = query("li a");
      assert.ok(link.href.endsWith("/u/ossaama/messages/grouperss"));
    });

    test("the item's link has a title for accessibility", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.strictEqual(link.title, I18n.t("notifications.titles.mentioned"));
    });

    test("has elements for label and description", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const label = query("li a .notification-label");
      const description = query("li a .notification-description");

      assert.strictEqual(
        label.textContent.trim(),
        "osama",
        "the label's content is the username by default"
      );

      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "the description defaults to the fancy_title"
      );
    });

    test("the description falls back to topic_title from data if fancy_title is absent", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: null,
        })
      );
      await render(template);
      const description = query("li a .notification-description");

      assert.strictEqual(
        description.textContent.trim(),
        "this is title before it becomes fancy <a>!",
        "topic_title from data is rendered safely"
      );
    });

    test("fancy_title is emoji-unescaped", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: "title with emoji :phone:",
        })
      );
      await render(template);
      assert.ok(
        exists("li a .notification-description img.emoji"),
        "emojis are unescaped when fancy_title is used for description"
      );
    });

    test("topic_title from data is not emoji-unescaped", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: null,
          data: {
            topic_title: "unsafe title with unescaped emoji :phone:",
          },
        })
      );
      await render(template);
      const description = query("li a .notification-description");

      assert.strictEqual(
        description.textContent.trim(),
        "unsafe title with unescaped emoji :phone:",
        "emojis aren't unescaped when topic title is not safe"
      );
      assert.ok(!query("img"), "no <img> exists");
    });

    test("various aspects can be customized according to the notification's render director", async function (assert) {
      withPluginApi("0.1", (api) => {
        api.registerNotificationTypeRenderer(
          "linked",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              get classNames() {
                return ["additional", "classes"];
              }

              get linkHref() {
                return "/somewhere/awesome";
              }

              get linkTitle() {
                return "hello world this is unsafe '\"<span>";
              }

              get icon() {
                return "wrench";
              }

              get label() {
                return "notification label 666 <span>";
              }

              get description() {
                return "notification description 123 <script>";
              }

              get labelWrapperClasses() {
                return ["label-wrapper-1"];
              }

              get descriptionWrapperClasses() {
                return ["description-class-1"];
              }
            };
          }
        );
      });

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.linked,
        })
      );

      await render(template);

      assert.ok(
        exists("li.additional.classes"),
        "extra classes are included on the item"
      );

      const link = query("li a");
      assert.ok(
        link.href.endsWith("/somewhere/awesome"),
        "link href is customized"
      );
      assert.strictEqual(
        link.title,
        "hello world this is unsafe '\"<span>",
        "link title is customized and rendered safely"
      );

      assert.ok(exists("svg.d-icon-wrench"), "icon is customized");

      const label = query("li .notification-label");
      assert.ok(
        label.classList.contains("label-wrapper-1"),
        "label wrapper has additional classes"
      );
      assert.strictEqual(
        label.textContent.trim(),
        "notification label 666 <span>",
        "label content is customized"
      );

      const description = query(".notification-description");
      assert.ok(
        description.classList.contains("description-class-1"),
        "description has additional classes"
      );
      assert.strictEqual(
        description.textContent.trim(),
        "notification description 123 <script>",
        "description content is customized"
      );
    });

    test("description can be omitted", async function (assert) {
      withPluginApi("0.1", (api) => {
        api.registerNotificationTypeRenderer(
          "linked",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              get description() {
                return null;
              }

              get label() {
                return "notification label";
              }
            };
          }
        );
      });

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.linked,
        })
      );

      await render(template);
      assert.notOk(
        exists(".notification-description"),
        "description is not rendered"
      );
      assert.ok(
        query("li").textContent.trim(),
        "notification label",
        "only label content is displayed"
      );
    });

    test("label can be omitted", async function (assert) {
      withPluginApi("0.1", (api) => {
        api.registerNotificationTypeRenderer(
          "linked",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              get label() {
                return null;
              }

              get description() {
                return "notification description";
              }
            };
          }
        );
      });

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.linked,
        })
      );

      await render(template);
      assert.ok(
        query("li").textContent.trim(),
        "notification description",
        "only notification description is displayed"
      );
      assert.notOk(exists(".notification-label"), "label is not rendered");
    });

    test("custom click handlers", async function (assert) {
      let klass;
      withPluginApi("0.1", (api) => {
        api.registerNotificationTypeRenderer(
          "linked",
          (NotificationItemBase) => {
            klass = class extends NotificationItemBase {
              static onClickCalled = false;

              get linkHref() {
                return "#";
              }

              onClick() {
                klass.onClickCalled = true;
              }
            };
            return klass;
          }
        );
      });

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.linked,
        })
      );

      await render(template);
      await click("li a");
      assert.ok(klass.onClickCalled);
    });
  }
);
