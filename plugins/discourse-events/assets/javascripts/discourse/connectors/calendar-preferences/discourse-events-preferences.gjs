import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default class DiscourseEventsPreferences extends Component {
  @service siteSettings;

  @service toasts;

  preferences = ["none", "notification", "personal_message"];

  get data() {
    return {
      event_reminder_preference:
        this.args.outletArgs.model.user_option.event_reminder_preference,
    };
  }

  @action
  async save(data) {
    const user = this.args.outletArgs.model;
    user.set(
      "user_option.event_reminder_preference",
      data.event_reminder_preference
    );
    await user.save(["event_reminder_preference"]);
    this.toasts.success({ data: { message: i18n("saved") } });
  }

  <template>
    {{#if
      (and
        this.siteSettings.discourse_post_event_enabled
        this.siteSettings.enable_improved_event_reminders
      )
    }}
      <section class="event-reminder-preferences">
        <h3>{{i18n "discourse_events.preferences.reminders.title"}}</h3>
        <p>{{i18n "discourse_events.preferences.reminders.description"}}</p>
        <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @format="large"
            @name="event_reminder_preference"
            @title={{i18n "discourse_events.preferences.reminders.preference"}}
            @type="select"
            as |field|
          >
            <field.Control @includeNone={{false}} as |select|>
              {{#each this.preferences as |preference|}}
                <select.Option @value={{preference}}>{{i18n
                    (concat
                      "discourse_events.preferences.reminders.preferences."
                      preference
                    )
                  }}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
          <form.Submit @label="submit" />
        </Form>
      </section>
    {{/if}}
  </template>
}
