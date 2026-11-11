import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  formatMuteEnd,
  MUTE_DURATIONS,
  mutedUntilFromNow,
} from "discourse/plugins/chat/discourse/lib/chat-mute-durations";

const NOTIFICATION_LEVELS = ["never", "mention", "always"];

export default class ChatRouteChannelPreferences extends Component {
  @service chatApi;
  @service currentUser;
  @service toasts;

  notificationLevels = NOTIFICATION_LEVELS;

  @cached
  get formData() {
    const membership = this.args.channel.currentUserMembership;

    return {
      mute: this.#muteValue(membership),
      notification_level: membership.notificationLevel,
    };
  }

  get muteOptions() {
    const membership = this.args.channel.currentUserMembership;
    const options = [
      { value: "off", label: i18n("chat.settings.mute_options.off") },
    ];

    if (membership.muted && membership.mutedUntil) {
      options.push({
        value: "current",
        label: i18n("chat.settings.mute_options.current", {
          until: formatMuteEnd(membership.mutedUntil, this.currentUser),
        }),
      });
    }

    MUTE_DURATIONS.forEach((duration) => {
      options.push({
        value: duration.id,
        label: i18n(`chat.settings.mute_options.${duration.id}`),
      });
    });

    options.push({
      value: "until_unmuted",
      label: i18n("chat.settings.mute_options.until_unmuted"),
    });

    return options;
  }

  @action
  registerFormApi(api) {
    this.formApi = api;
  }

  @action
  async onMuteChange(value, { name, set }) {
    const previousValue = this.formData[name];
    set(name, value);

    const duration = MUTE_DURATIONS.find((d) => d.id === value);
    const settings = { muted: value !== "off" };
    if (duration) {
      settings.muted_until = mutedUntilFromNow(duration.minutes);
    }

    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.args.channel.id,
          settings
        );

      const membership = this.args.channel.currentUserMembership;
      membership.muted = result.membership.muted;
      membership.mutedUntil = result.membership.muted_until
        ? new Date(result.membership.muted_until)
        : null;

      set(name, this.#muteValue(membership));
      this.formApi.commitField(name);
      this.toasts.success({ data: { message: i18n("saved") } });
    } catch (error) {
      set(name, previousValue);
      this.formApi.commitField(name);
      popupAjaxError(error);
    }
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
      membership.notificationLevel = result.membership.notification_level;
      this.toasts.success({ data: { message: i18n("saved") } });
    } catch (error) {
      set(name, previousValue);
      this.formApi.commitField(name);
      popupAjaxError(error);
    }
  }

  #muteValue(membership) {
    if (!membership.muted) {
      return "off";
    }

    return membership.mutedUntil ? "current" : "until_unmuted";
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
          @name="mute"
          @onSet={{this.onMuteChange}}
          @showOptional={{false}}
          @title={{i18n "chat.settings.mute"}}
          @type="select"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            {{#each this.muteOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.label}}
              </select.Option>
            {{/each}}
          </field.Control>
        </form.Field>

        {{#if (eq transientData.mute "off")}}
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
        {{/if}}
      </Form>
    </div>
  </template>
}
