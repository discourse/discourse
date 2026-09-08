import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import ChatForm from "discourse/plugins/chat/discourse/components/chat/form";
import ChatModalArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import ChatRetentionReminderText from "discourse/plugins/chat/discourse/components/chat-retention-reminder-text";
import ToggleChannelMembershipButton from "discourse/plugins/chat/discourse/components/toggle-channel-membership-button";

const NOTIFICATION_LEVELS = [
  { name: i18n("chat.notification_levels.never"), value: "never" },
  { name: i18n("chat.notification_levels.mention"), value: "mention" },
  { name: i18n("chat.notification_levels.always"), value: "always" },
];

export default class ChatRouteChannelInfoSettings extends Component {
  @service chatApi;
  @service chatGuardian;
  @service chatChannelsManager;
  @service siteSettings;
  @service dialog;
  @service modal;
  @service site;
  @service toasts;
  @service router;

  notificationLevels = NOTIFICATION_LEVELS;

  settingsSectionTitle = i18n("chat.settings.settings_title");
  channelInfoSectionTitle = i18n("chat.settings.info_title");
  categoryLabel = i18n("chat.settings.category_label");
  historyLabel = i18n("chat.settings.history_label");
  adminSectionTitle = i18n("chat.settings.admin_title");
  membersLabel = i18n("chat.channel_info.tabs.members");
  descriptionSectionTitle = i18n("chat.about_view.description");
  titleSectionTitle = i18n("chat.about_view.title");
  descriptionPlaceholder = i18n(
    "chat.channel_edit_description_modal.description"
  );
  toggleThreadingLabel = i18n("chat.settings.channel_threading_label");
  toggleThreadingDescription = i18n(
    "chat.settings.channel_threading_description"
  );
  muteSectionLabel = i18n("chat.settings.mute");
  channelWideMentionsLabel = i18n("chat.settings.channel_wide_mentions_label");
  autoJoinLabel = i18n("chat.settings.auto_join_users_label");
  notificationsLevelLabel = i18n("chat.settings.notification_level");

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

  get canToggleChannelState() {
    return this.args.channel.isClosed;
  }

  get openChannelDisabledReason() {
    if (this.args.channel.isArchived) {
      return i18n("chat.channel_settings.open_channel_disabled_archived");
    }
    return i18n("chat.channel_settings.open_channel_disabled_read_only");
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
    return i18n("chat.settings.channel_wide_mentions_description", {
      channel: this.args.channel.title,
    });
  }

  get isChannelMuted() {
    return this.args.channel.currentUserMembership.muted;
  }

  get shouldRenderMuteSection() {
    return this.args.channel.currentUserMembership.following;
  }

  get shouldRenderChannelWideMentionsAvailable() {
    return this.args.channel.isCategoryChannel;
  }

  get shouldRenderNotificationsLevelSection() {
    return (
      this.args.channel.currentUserMembership.following && !this.isChannelMuted
    );
  }

  get autoJoinAvailable() {
    return (
      this.siteSettings.max_chat_auto_joined_users > 0 &&
      this.args.channel.isCategoryChannel &&
      this.args.channel.isOpen
    );
  }

  get shouldRenderSettingsSection() {
    return (
      this.args.channel.isOpen &&
      (this.shouldRenderMuteSection ||
        this.shouldRenderNotificationsLevelSection ||
        this.toggleThreadingDirectMessage)
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
      message: i18n("chat.settings.auto_join_users_warning", {
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
      this.toasts.success({ data: { message: i18n("saved") } });
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

  @action
  async _updateChannelProperty(channel, property, value) {
    try {
      const result = await this.chatApi.updateChannel(channel.id, {
        [property]: value,
      });
      this.toasts.success({ data: { message: i18n("saved") } });
      return result;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="c-routes --channel-info-settings">
      <div class="c-channel-settings">
        <ChatForm as |form|>
          <form.section @title={{this.titleSectionTitle}} as |section|>
            <section.row>
              <:default>
                <div class="c-channel-settings__name">
                  {{dReplaceEmoji @channel.title}}
                </div>

                {{#if @channel.isCategoryChannel}}
                  <div class="c-channel-settings__slug">
                    <LinkTo
                      @models={{@channel.routeModels}}
                      @route="chat.channel"
                    >
                      /chat/c/{{@channel.slug}}/{{@channel.id}}
                    </LinkTo>
                  </div>
                {{/if}}
              </:default>

              <:action>
                {{#if this.canEditChannel}}
                  <DButton
                    class="edit-name-slug-btn btn-flat"
                    @action={{this.onEditChannelTitle}}
                    @label="chat.channel_settings.edit"
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
                      class="edit-description-btn btn-flat"
                      @action={{this.onEditChannelDescription}}
                      @label={{if
                        @channel.description.length
                        "chat.channel_settings.edit"
                        "chat.channel_settings.add"
                      }}
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

          {{#if this.shouldRenderSettingsSection}}
            <form.section @title={{this.settingsSectionTitle}} as |section|>
              {{#if this.shouldRenderMuteSection}}
                <section.row @label={{this.muteSectionLabel}}>
                  <:action>
                    <DToggleSwitch
                      class="c-channel-settings__mute-switch"
                      @state={{@channel.currentUserMembership.muted}}
                      {{on "click" this.onToggleMuted}}
                    />
                  </:action>
                </section.row>
              {{/if}}

              {{#if this.shouldRenderNotificationsLevelSection}}
                <section.row @label={{this.notificationsLevelLabel}}>
                  <:action>
                    <ComboBox
                      class="c-channel-settings__selector c-channel-settings__notifications-selector"
                      @content={{this.notificationLevels}}
                      @onChange={{fn
                        this.saveNotificationSettings
                        "notificationLevel"
                        "notification_level"
                      }}
                      @value={{@channel.currentUserMembership.notificationLevel}}
                      @valueProperty="value"
                    />
                  </:action>
                </section.row>
              {{/if}}

              {{#if this.toggleThreadingDirectMessage}}
                <section.row @label={{this.toggleThreadingLabel}}>
                  <:action>
                    <DToggleSwitch
                      class="c-channel-settings__threading-switch"
                      @state={{@channel.threadingEnabled}}
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
                {{dCategoryBadge
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
              data-section="admin"
              @title={{this.adminSectionTitle}}
              as |section|
            >
              {{#if this.autoJoinAvailable}}
                <section.row @label={{this.autoJoinLabel}}>
                  <:action>
                    <DToggleSwitch
                      class="c-channel-settings__auto-join-switch"
                      @state={{@channel.autoJoinUsers}}
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
                      class="c-channel-settings__threading-switch"
                      @state={{@channel.threadingEnabled}}
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
                        class="archive-btn chat-form__btn btn-transparent"
                        @action={{this.onArchiveChannel}}
                        @icon="box-archive"
                        @label="chat.channel_settings.archive_channel"
                      />
                    </:action>
                  </section.row>
                {{/if}}

                <section.row>
                  <:action>
                    {{#if @channel.isOpen}}
                      <DButton
                        class="close-btn chat-form__btn btn-transparent"
                        @action={{this.onToggleChannelState}}
                        @icon="lock"
                        @label="chat.channel_settings.close_channel"
                      />
                    {{else if this.canToggleChannelState}}
                      <DButton
                        class="open-btn chat-form__btn btn-transparent"
                        @action={{this.onToggleChannelState}}
                        @icon="unlock"
                        @label="chat.channel_settings.open_channel"
                      />
                    {{else}}
                      <DTooltip
                        @identifier="channel-open-disabled"
                        @placement="left"
                      >
                        <:trigger>
                          <DButton
                            class="open-btn chat-form__btn btn-transparent"
                            @disabled={{true}}
                            @icon="unlock"
                            @label="chat.channel_settings.open_channel"
                          />
                        </:trigger>
                        <:content>
                          {{this.openChannelDisabledReason}}
                        </:content>
                      </DTooltip>
                    {{/if}}
                  </:action>
                </section.row>

                <section.row>
                  <:action>
                    <DButton
                      class="delete-btn chat-form__btn btn-transparent"
                      @action={{this.onDeleteChannel}}
                      @icon="trash-can"
                      @label="chat.channel_settings.delete_channel"
                    />
                  </:action>
                </section.row>
              {{/if}}

            </form.section>
          {{/if}}

          <form.section class="--leave-channel" as |section|>
            {{#if @channel.chatable.group}}
              <div class="c-channel-settings__leave-info">
                {{dIcon "triangle-exclamation"}}
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
                    leaveDestructive=true
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
