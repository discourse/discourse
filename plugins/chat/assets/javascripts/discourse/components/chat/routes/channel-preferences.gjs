import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const NOTIFICATION_LEVELS = ["never", "mention", "always"];

export default class ChatRouteChannelPreferences extends Component {
  @service chatApi;
  @service toasts;

  notificationLevels = NOTIFICATION_LEVELS;

  @cached
  get formData() {
    const membership = this.args.channel.currentUserMembership;

    return {
      muted: membership.muted,
      notification_level: membership.notificationLevel,
    };
  }

  @action
  registerFormApi(api) {
    this.formApi = api;
  }

  @action
  async onNotificationSettingChange(value, { name, set }) {
    const previousValue = this.formData[name];
    set(name, value);

    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.args.channel.id,
          { [name]: value }
        );

      const membership = this.args.channel.currentUserMembership;
      membership.muted = result.membership.muted;
      membership.notificationLevel = result.membership.notification_level;
      this.toasts.success({ data: { message: i18n("saved") } });
    } catch (error) {
      set(name, previousValue);
      this.formApi.commitField(name);
      popupAjaxError(error);
    }
  }

  <template>
    <div class="c-channel-preferences">
      <h1 class="sr-only">{{i18n
          "chat.channel_info.preferences_title"
          channel=@channel.title
        }}</h1>

      <Form
        class="c-channel-preferences__form"
        @data={{this.formData}}
        @onRegisterApi={{this.registerFormApi}}
        as |form transientData|
      >
        <form.Field
          @name="muted"
          @onSet={{this.onNotificationSettingChange}}
          @showOptional={{false}}
          @title={{i18n "chat.settings.mute"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>

        {{#unless transientData.muted}}
          <form.Field
            @name="notification_level"
            @onSet={{this.onNotificationSettingChange}}
            @showOptional={{false}}
            @title={{i18n "chat.settings.notification_level"}}
            @type="select"
            as |field|
          >
            <field.Control @includeNone={{false}} as |select|>
              {{#each this.notificationLevels as |level|}}
                <select.Option @value={{level}}>
                  {{i18n (concat "chat.notification_levels." level)}}
                </select.Option>
              {{/each}}
            </field.Control>
          </form.Field>
        {{/unless}}
      </Form>
    </div>
  </template>
}
