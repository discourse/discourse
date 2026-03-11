import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const BOOSTS_ATTRS = ["boost_notifications_level"];

const BOOST_NOTIFICATIONS_LEVELS = [
  {
    name: "discourse_boosts.user_option.boost_notifications_levels.all",
    value: 0,
  },
  {
    name: "discourse_boosts.user_option.boost_notifications_levels.consolidated",
    value: 1,
  },
  {
    name: "discourse_boosts.user_option.boost_notifications_levels.disabled",
    value: 2,
  },
];

export default class BoostsPreferences extends Component {
  @tracked saved = false;

  get notificationLevelOptions() {
    return BOOST_NOTIFICATIONS_LEVELS.map((option) => ({
      name: i18n(option.name),
      value: option.value,
    }));
  }

  get formData() {
    return {
      boost_notifications_level:
        this.args.model.user_option.boost_notifications_level,
    };
  }

  @action
  handleSubmit(data) {
    this.saved = false;

    for (const [key, value] of Object.entries(data)) {
      this.args.model.set(`user_option.${key}`, value);
    }

    return this.args.model
      .save(BOOSTS_ATTRS)
      .then(() => {
        this.saved = true;
      })
      .catch(popupAjaxError);
  }

  <template>
    <Form @data={{this.formData}} @onSubmit={{this.handleSubmit}} as |form|>
      <form.Field
        @title={{i18n "discourse_boosts.user_option.boost_notifications_level"}}
        @name="boost_notifications_level"
        @format="large"
        as |field|
      >
        <field.Select @includeNone={{false}} as |select|>
          {{#each this.notificationLevelOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.name}}
            </select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <div class="save-controls">
        <form.Submit />
        {{#if this.saved}}
          <span class="saved">{{i18n "saved"}}</span>
        {{/if}}
      </div>
    </Form>
  </template>
}
