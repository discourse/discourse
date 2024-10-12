import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import categoryBadge from "discourse/helpers/category-badge";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import ChatForm from "discourse/plugins/chat/discourse/components/chat/form";
import ChatModalArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import ChatRetentionReminderText from "discourse/plugins/chat/discourse/components/chat-retention-reminder-text";
import ToggleChannelMembershipButton from "discourse/plugins/chat/discourse/components/toggle-channel-membership-button";

const NOTIFICATION_LEVELS = [
  { name: I18n.t("chat.notification_levels.never"), value: "never" },
  { name: I18n.t("chat.notification_levels.mention"), value: "mention" },
  { name: I18n.t("chat.notification_levels.always"), value: "always" },
];

export default class ChatRouteChannelInfoSettings extends Component {
  @service chatApi;
  @service chatGuardian;
  @service chatChannelsManager;
  @service currentUser;
  @service siteSettings;
  @service dialog;
  @service modal;
  @service site;
  @service toasts;
  @service router;

  notificationLevels = NOTIFICATION_LEVELS;

  settingsSectionTitle = I18n.t("chat.settings.settings_title");
  channelInfoSectionTitle = I18n.t("chat.settings.info_title");
  categoryLabel = I18n.t("chat.settings.category_label");
  historyLabel = I18n.t("chat.settings.history_label");
  adminSectionTitle = I18n.t("chat.settings.admin_title");
  membersLabel = I18n.t("chat.channel_info.tabs.members");
  descriptionSectionTitle = I18n.t("chat.about_view.description");
  titleSectionTitle = I18n.t("chat.about_view.title");
  descriptionPlaceholder = I18n.t(
    "chat.channel_edit_description_modal.description"
  );
  toggleThreadingLabel = I18n.t("chat.settings.channel_threading_label");
  toggleThreadingDescription = I18n.t(
    "chat.settings.channel_threading_description"
  );
  muteSectionLabel = I18n.t("chat.settings.mute");
  channelWideMentionsLabel = I18n.t(
    "chat.settings.channel_wide_mentions_label"
  );
  autoJoinLabel = I18n.t("chat.settings.auto_join_users_label");
  notificationsLevelLabel = I18n.t("chat.settings.notification_level");

  get canEditChannel() {
    if (
      this.args.channel.isCategoryChannel &&
      this.chatGuardian.canEditChatChannel()
    ) {
      return true;
    }

    if (
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.chatable.group
    ) {
      return true;
    }

    return false;
  }

  get shouldRenderDescriptionSection() {
    return this.args.channel.isCategoryChannel;
  }

  get shouldRenderStatusSection() {
    return this.args.channel.isCategoryChannel;
  }

  get shouldRenderArchiveRow() {
    return this.chatGuardian.canArchiveChannel(this.args.channel);
  }

  get toggleChannelWideMentionsAvailable() {
    return this.args.channel.isCategoryChannel && this.args.channel.isOpen;
  }

  get toggleThreadingCategoryChannel() {
    return this.args.channel.isCategoryChannel && this.args.channel.isOpen;
  }

  get toggleThreadingDirectMessage() {
    return this.args.channel.isDirectMessageChannel && this.args.channel.isOpen;
  }

  get channelWideMentionsDescription() {
    return I18n.t("chat.settings.channel_wide_mentions_description", {
      channel: this.args.channel.title,
    });
  }

  get isChannelMuted() {
    return this.args.channel.currentUserMembership.muted;
  }

  get shouldRenderChannelWideMentionsAvailable() {
    return this.args.channel.isCategoryChannel;
  }

  get shouldRenderNotificationsLevelSection() {
    return !this.isChannelMuted;
  }

  get autoJoinAvailable() {
    return (
      this.siteSettings.max_chat_auto_joined_users > 0 &&
      this.args.channel.isCategoryChannel &&
      this.args.channel.isOpen
    );
  }

  get shouldRenderAdminSection() {
    return (
      this.canEditChannel &&
      (this.toggleChannelWideMentionsAvailable ||
        this.args.channel.isCategoryChannel)
    );
  }

  @action
  async onToggleChannelWideMentions() {
    const newValue = !this.args.channel.allowChannelWideMentions;

    if (this.args.channel.allowChannelWideMentions === newValue) {
      return;
    }

    try {
      this.args.channel.allowChannelWideMentions = newValue;

      const result = await this._updateChannelProperty(
        this.args.channel,
        "allow_channel_wide_mentions",
        newValue
      );

      this.args.channel.allowChannelWideMentions =
        result.channel.allow_channel_wide_mentions;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onToggleAutoJoinUsers() {
    if (this.args.channel.autoJoinUsers) {
      return await this.onDisableAutoJoinUsers();
    }

    return await this.onEnableAutoJoinUsers();
  }

  @action
  async onDisableAutoJoinUsers() {
    if (this.args.channel.autoJoinUsers === false) {
      return;
    }

    try {
      this.args.channel.autoJoinUsers = false;

      const result = await this._updateChannelProperty(
        this.args.channel,
        "auto_join_users",
        false
      );

      this.args.channel.autoJoinUsers = result.channel.auto_join_users;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onEnableAutoJoinUsers() {
    if (this.args.channel.autoJoinUsers === true) {
      return;
    }

    return this.dialog.confirm({
      message: I18n.t("chat.settings.auto_join_users_warning", {
        category: this.args.channel.chatable.name,
      }),
      didConfirm: async () => {
        try {
          const result = await this._updateChannelProperty(
            this.args.channel,
            "auto_join_users",
            true
          );

          this.args.channel.autoJoinUsers = result.channel.auto_join_users;
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  onToggleMuted() {
    const newValue = !this.args.channel.currentUserMembership.muted;
    this.saveNotificationSettings("muted", "muted", newValue);
  }

  @action
  async saveNotificationSettings(frontendKey, backendKey, newValue) {
    if (this.args.channel.currentUserMembership[frontendKey] === newValue) {
      return;
    }

    this.args.channel.currentUserMembership[frontendKey] = newValue;

    const settings = {};
    settings[backendKey] = newValue;

    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.args.channel.id,
          settings
        );

      this.args.channel.currentUserMembership[frontendKey] =
        result.membership[backendKey];
      this.toasts.success({ data: { message: I18n.t("saved") } });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async _updateChannelProperty(channel, property, value) {
    try {
      const result = await this.chatApi.updateChannel(channel.id, {
        [property]: value,
      });
      this.toasts.success({ data: { message: I18n.t("saved") } });
      return result;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onToggleThreadingEnabled(value) {
    try {
      this.args.channel.threadingEnabled = !value;
      const result = await this._updateChannelProperty(
        this.args.channel,
        "threading_enabled",
        !value
      );
      this.args.channel.threadingEnabled = result.channel.threading_enabled;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onToggleChannelState() {
    return this.modal.show(ChatModalToggleChannelStatus, {
      model: this.args.channel,
    });
  }

  @action
  onArchiveChannel() {
    return this.modal.show(ChatModalArchiveChannel, {
      model: { channel: this.args.channel },
    });
  }

  @action
  onDeleteChannel() {
    return this.modal.show(ChatModalDeleteChannel, {
      model: { channel: this.args.channel },
    });
  }

  @action
  onEditChannelTitle() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.args.channel,
    });
  }

  @action
  onLeaveChannel(channel) {
    this.chatChannelsManager.remove(channel);
    return this.router.transitionTo("chat");
  }

  @action
  onEditChannelDescription() {
    return this.modal.show(ChatModalEditChannelDescription, {
      model: this.args.channel,
    });
  }

  <template>
    <div class="c-routes --channel-info-settings">
      <div class="c-channel-settings">
        <ChatForm as |form|>
          <form.section @title={{this.titleSectionTitle}} as |section|>
            <section.row>
              <:default>
                <div class="c-channel-settings__name">
                  {{replaceEmoji @channel.title}}
                </div>

                {{#if @channel.isCategoryChannel}}
                  <div class="c-channel-settings__slug">
                    <LinkTo
                      @route="chat.channel"
                      @models={{@channel.routeModels}}
                    >
                      /chat/c/{{@channel.slug}}/{{@channel.id}}
                    </LinkTo>
                  </div>
                {{/if}}
              </:default>

              <:action>
                {{#if this.canEditChannel}}
                  <DButton
                    @label="chat.channel_settings.edit"
                    @action={{this.onEditChannelTitle}}
                    class="edit-name-slug-btn btn-flat"
                  />
                {{/if}}
              </:action>

            </section.row>
          </form.section>

          {{#if this.shouldRenderDescriptionSection}}
            <form.section @title={{this.descriptionSectionTitle}} as |section|>
              <section.row>
                <:default>
                  {{#if @channel.description.length}}
                    {{@channel.description}}
                  {{else}}
                    {{this.descriptionPlaceholder}}
                  {{/if}}
                </:default>

                <:action>
                  {{#if this.canEditChannel}}
                    <DButton
                      @label={{if
                        @channel.description.length
                        "chat.channel_settings.edit"
                        "chat.channel_settings.add"
                      }}
                      @action={{this.onEditChannelDescription}}
                      class="edit-description-btn btn-flat"
                    />
                  {{/if}}
                </:action>
              </section.row>
            </form.section>
          {{/if}}

          {{#if this.site.mobileView}}
            <form.section as |section|>
              <section.row
                @label={{this.membersLabel}}
                @route="chat.channel.info.members"
                @routeModels={{@channel.routeModels}}
              />
            </form.section>
          {{/if}}

          {{#if @channel.isOpen}}
            <form.section @title={{this.settingsSectionTitle}} as |section|>
              <section.row @label={{this.muteSectionLabel}}>
                <:action>
                  <DToggleSwitch
                    @state={{@channel.currentUserMembership.muted}}
                    class="c-channel-settings__mute-switch"
                    {{on "click" this.onToggleMuted}}
                  />
                </:action>
              </section.row>

              {{#if this.shouldRenderNotificationsLevelSection}}
                <section.row @label={{this.notificationsLevelLabel}}>
                  <:action>
                    <ComboBox
                      @content={{this.notificationLevels}}
                      @value={{@channel.currentUserMembership.notificationLevel}}
                      @valueProperty="value"
                      @onChange={{fn
                        this.saveNotificationSettings
                        "notificationLevel"
                        "notification_level"
                      }}
                      class="c-channel-settings__selector c-channel-settings__notifications-selector"
                    />
                  </:action>
                </section.row>
              {{/if}}

              {{#if this.toggleThreadingDirectMessage}}
                <section.row @label={{this.toggleThreadingLabel}}>
                  <:action>
                    <DToggleSwitch
                      @state={{@channel.threadingEnabled}}
                      class="c-channel-settings__threading-switch"
                      {{on
                        "click"
                        (fn
                          this.onToggleThreadingEnabled
                          @channel.threadingEnabled
                        )
                      }}
                    />
                  </:action>

                  <:description>
                    {{this.toggleThreadingDescription}}
                  </:description>
                </section.row>
              {{/if}}
            </form.section>
          {{/if}}

          <form.section @title={{this.channelInfoSectionTitle}} as |section|>
            {{#if @channel.isCategoryChannel}}
              <section.row @label={{this.categoryLabel}}>
                {{categoryBadge
                  @channel.chatable
                  link=true
                  allowUncategorized=true
                }}
              </section.row>
            {{/if}}

            <section.row @label={{this.historyLabel}}>
              <ChatRetentionReminderText @channel={{@channel}} @type="short" />
            </section.row>
          </form.section>

          {{#if this.shouldRenderAdminSection}}
            <form.section
              @title={{this.adminSectionTitle}}
              data-section="admin"
              as |section|
            >
              {{#if this.autoJoinAvailable}}
                <section.row @label={{this.autoJoinLabel}}>
                  <:action>
                    <DToggleSwitch
                      @state={{@channel.autoJoinUsers}}
                      class="c-channel-settings__auto-join-switch"
                      {{on
                        "click"
                        (fn this.onToggleAutoJoinUsers @channel.autoJoinUsers)
                      }}
                    />
                  </:action>
                </section.row>
              {{/if}}

              {{#if this.toggleChannelWideMentionsAvailable}}
                <section.row @label={{this.channelWideMentionsLabel}}>
                  <:action>
                    <DToggleSwitch
                      class="c-channel-settings__channel-wide-mentions"
                      @state={{@channel.allowChannelWideMentions}}
                      {{on
                        "click"
                        (fn
                          this.onToggleChannelWideMentions
                          @channel.allowChannelWideMentions
                        )
                      }}
                    />
                  </:action>

                  <:description>
                    {{this.channelWideMentionsDescription}}
                  </:description>
                </section.row>
              {{/if}}

              {{#if this.toggleThreadingCategoryChannel}}
                <section.row @label={{this.toggleThreadingLabel}}>
                  <:action>
                    <DToggleSwitch
                      @state={{@channel.threadingEnabled}}
                      class="c-channel-settings__threading-switch"
                      {{on
                        "click"
                        (fn
                          this.onToggleThreadingEnabled
                          @channel.threadingEnabled
                        )
                      }}
                    />
                  </:action>

                  <:description>
                    {{this.toggleThreadingDescription}}
                  </:description>
                </section.row>
              {{/if}}

              {{#if this.shouldRenderStatusSection}}
                {{#if this.shouldRenderArchiveRow}}
                  <section.row>
                    <:action>
                      <DButton
                        @action={{this.onArchiveChannel}}
                        @label="chat.channel_settings.archive_channel"
                        @icon="box-archive"
                        class="archive-btn chat-form__btn btn-transparent"
                      />
                    </:action>
                  </section.row>
                {{/if}}

                <section.row>
                  <:action>
                    {{#if @channel.isOpen}}
                      <DButton
                        @action={{this.onToggleChannelState}}
                        @label="chat.channel_settings.close_channel"
                        @icon="lock"
                        class="close-btn chat-form__btn btn-transparent"
                      />
                    {{else}}
                      <DButton
                        @action={{this.onToggleChannelState}}
                        @label="chat.channel_settings.open_channel"
                        @icon="unlock"
                        class="open-btn chat-form__btn btn-transparent"
                      />
                    {{/if}}
                  </:action>
                </section.row>

                <section.row>
                  <:action>
                    <DButton
                      @action={{this.onDeleteChannel}}
                      @label="chat.channel_settings.delete_channel"
                      @icon="trash-can"
                      class="delete-btn chat-form__btn btn-transparent"
                    />
                  </:action>
                </section.row>
              {{/if}}

            </form.section>
          {{/if}}

          <form.section class="--leave-channel" as |section|>
            {{#if @channel.chatable.group}}
              <div class="c-channel-settings__leave-info">
                {{icon "triangle-exclamation"}}
                {{i18n "chat.channel_settings.leave_groupchat_info"}}
              </div>
            {{/if}}
            <section.row>
              <:action>
                <ToggleChannelMembershipButton
                  @channel={{@channel}}
                  @onLeave={{this.onLeaveChannel}}
                  @options={{hash
                    joinClass="btn-primary"
                    leaveClass="btn-danger"
                    joinIcon="right-to-bracket"
                    leaveIcon="right-from-bracket"
                  }}
                />
              </:action>
            </section.row>
          </form.section>
        </ChatForm>
      </div>
    </div>
  </template>
}
