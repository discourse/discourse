import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import User, { addSaveableUserOptionField } from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";
import DiscourseEventsPreferences from "../../discourse/connectors/calendar-preferences/discourse-events-preferences";

module(
  "Integration | Component | DiscourseEventsPreferences",
  function (hooks) {
    setupRenderingTest(hooks);

    test("loads and saves the native delivery selector", async function (assert) {
      this.siteSettings.discourse_post_event_enabled = true;
      this.siteSettings.enable_improved_event_reminders = true;
      addSaveableUserOptionField("event_reminder_preference");
      this.user = User.create({
        username: "sam",
        user_option: { event_reminder_preference: "personal_message" },
      });
      let saved;
      pretender.put("/u/sam.json", (request) => {
        saved = new URLSearchParams(request.requestBody).get(
          "event_reminder_preference"
        );
        return response({ user: { username: "sam" } });
      });
      await render(
        <template>
          <DiscourseEventsPreferences @outletArgs={{hash model=this.user}} />
        </template>
      );
      assert
        .dom("select.d-native-select")
        .hasValue(
          "personal_message",
          "uses the current channel in a native select"
        );
      await form().field("event_reminder_preference").select("notification");
      await form().submit();
      assert.strictEqual(
        saved,
        "notification",
        "saves the selected preference"
      );
      const toasts = this.owner.lookup("service:toasts").activeToasts;
      assert.strictEqual(toasts.length, 1, "shows a confirmation toast");
      assert.strictEqual(
        toasts[0].options.data.message,
        "Saved!",
        "confirms the save"
      );
      assert.strictEqual(
        toasts[0].options.data.theme,
        "success",
        "uses a success toast"
      );
    });

    test("does not show preferences when events are disabled", async function (assert) {
      this.siteSettings.discourse_post_event_enabled = false;
      this.siteSettings.enable_improved_event_reminders = true;
      await render(<template><DiscourseEventsPreferences /></template>);
      assert
        .dom(".event-reminder-preferences")
        .doesNotExist("does not offer disabled settings");
    });

    test("does not show preferences before the upcoming change is enabled", async function (assert) {
      this.siteSettings.discourse_post_event_enabled = true;
      this.siteSettings.enable_improved_event_reminders = false;
      await render(<template><DiscourseEventsPreferences /></template>);
      assert
        .dom(".event-reminder-preferences")
        .doesNotExist("does not expose the upcoming preference");
    });
  }
);
