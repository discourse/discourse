import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TopicAdminMenu extends Component {
  @service adminTopicMenuButtons;
  @service currentUser;
  @service siteSettings;

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async onButtonAction(buttonAction) {
    await this.dMenu.close();
    this.args[buttonAction]?.();
  }

  @action
  async onExtraButtonAction(buttonAction) {
    await this.dMenu.close();
    buttonAction?.();
  }

  get extraButtons() {
    return this.adminTopicMenuButtons.callbacks
      .map((callback) => {
        return callback(this.args.topic);
      })
      .filter(Boolean);
  }

  get extraButtonGroups() {
    const groups = [];
    let currentGroup = null;

    for (const button of this.extraButtons) {
      const sectionId = button.section?.id ?? null;

      if (!currentGroup || currentGroup.id !== sectionId) {
        let sectionLabel = null;
        if (button.section) {
          sectionLabel =
            button.section.translatedLabel ??
            (button.section.label ? i18n(button.section.label) : null);
        }

        currentGroup = {
          id: sectionId,
          label: sectionLabel,
          buttons: [],
        };
        groups.push(currentGroup);
      }

      currentGroup.buttons.push(button);
    }

    return groups;
  }

  get details() {
    return this.args.topic.get("details");
  }

  get isPrivateMessage() {
    return this.args.topic.get("isPrivateMessage");
  }

  get featured() {
    return (
      !!this.args.topic.get("pinned_at") || this.args.topic.get("isBanner")
    );
  }

  get visible() {
    return this.args.topic.get("visible");
  }

  get canDelete() {
    return this.details.get("can_delete");
  }

  get canRecover() {
    return this.details.get("can_recover");
  }

  get archived() {
    return this.args.topic.get("archived");
  }

  get topicModerationHistoryUrl() {
    return getURL(`/review?topic_id=${this.args.topic.id}&status=all`);
  }

  get showAdminButton() {
    return (
      this.currentUser?.canManageTopic ||
      this.currentUser?.canSetTopicTimer ||
      this.details?.can_archive_topic ||
      this.details?.can_close_topic ||
      this.details?.can_split_merge_topic
    );
  }

  get showTopicTimerItem() {
    return this.currentUser?.canSetTopicTimer;
  }

  get showTopicManagementSection() {
    return this.currentUser?.canManageTopic || this.showTopicTimerItem;
  }

  get showTopicManagementSectionDivider() {
    const showsMultiSelect =
      this.currentUser?.canManageTopic || this.details?.can_split_merge_topic;
    const showsDeleteOrRecover =
      (this.currentUser?.canManageTopic ||
        this.details?.can_moderate_category) &&
      (this.canDelete || this.canRecover);
    const showsPin =
      this.details?.can_pin_unpin_topic &&
      !this.isPrivateMessage &&
      (this.visible || this.featured || this.details?.can_banner_topic);
    const showsArchive =
      this.details?.can_archive_topic && !this.isPrivateMessage;

    return (
      this.showTopicManagementSection &&
      (showsMultiSelect ||
        showsDeleteOrRecover ||
        this.details?.can_close_topic ||
        showsPin ||
        showsArchive ||
        this.details?.can_toggle_topic_visibility ||
        this.details?.can_convert_topic)
    );
  }

  get showNestedRepliesToggle() {
    return (
      this.siteSettings.nested_replies_enabled &&
      !this.siteSettings.nested_replies_default &&
      this.currentUser?.staff
    );
  }

  get nestedRepliesToggleLabel() {
    return this.args.topic.get("is_nested_view")
      ? "nested_replies.topic_admin_menu.disable_nested_replies"
      : "nested_replies.topic_admin_menu.enable_nested_replies";
  }

  @action
  async toggleNestedReplies() {
    await this.dMenu.close();
    const topic = this.args.topic;
    const newValue = !topic.get("is_nested_view");
    const topicId = topic.get("id");
    const slug = topic.get("slug");

    try {
      await ajax(`/n/${slug}/${topicId}/toggle`, {
        type: "PUT",
        data: { enabled: newValue },
      });
      topic.set("is_nested_view", newValue);
      topic.set("_forcedFlat", !newValue);

      if (newValue) {
        DiscourseURL.routeTo(`/t/${slug}/${topicId}`);
      } else {
        DiscourseURL.routeTo(`/t/${slug}/${topicId}`);
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if this.showAdminButton}}
      <DMenu
        @identifier="topic-admin-menu"
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @autofocus={{true}}
        @triggerClass="btn-default btn-icon toggle-admin-menu {{@buttonClasses}}"
      >
        <:trigger>
          {{dIcon "wrench"}}
        </:trigger>
        <:content>
          <DDropdownMenu as |dropdown|>
            {{#if
              (or
                this.currentUser.canManageTopic
                this.details.can_split_merge_topic
              )
            }}
              <dropdown.item class="topic-admin-multi-select">
                <DButton
                  @label="topic.actions.multi_select"
                  @action={{fn this.onButtonAction "toggleMultiSelect"}}
                  @icon="list-check"
                />
              </dropdown.item>
            {{/if}}

            {{#if
              (or
                this.currentUser.canManageTopic
                this.details.can_moderate_category
              )
            }}
              {{#if this.canDelete}}
                <dropdown.item class="topic-admin-delete">
                  <DButton
                    @label="topic.actions.delete"
                    @action={{fn this.onButtonAction "deleteTopic"}}
                    @icon="trash-can"
                    class="popup-menu-btn-danger --danger"
                  />
                </dropdown.item>
              {{else if this.canRecover}}
                <dropdown.item class="topic-admin-recover">
                  <DButton
                    @label="topic.actions.recover"
                    @action={{fn this.onButtonAction "recoverTopic"}}
                    @icon="arrow-rotate-left"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}

            {{#if this.details.can_close_topic}}
              <dropdown.item
                class={{if
                  @topic.closed
                  "topic-admin-open"
                  "topic-admin-close"
                }}
              >
                <DButton
                  @label={{if
                    @topic.closed
                    "topic.actions.open"
                    "topic.actions.close"
                  }}
                  @action={{fn this.onButtonAction "toggleClosed"}}
                  @icon={{if @topic.closed "topic.opened" "topic.closed"}}
                />
              </dropdown.item>
            {{/if}}

            {{#if
              (and
                this.details.can_pin_unpin_topic
                (not this.isPrivateMessage)
                (or this.visible this.featured this.details.can_banner_topic)
              )
            }}
              <dropdown.item class="topic-admin-pin">
                <DButton
                  @label={{if
                    this.featured
                    "topic.actions.unpin"
                    "topic.actions.pin"
                  }}
                  @action={{fn this.onButtonAction "showFeatureTopic"}}
                  @icon="thumbtack"
                />
              </dropdown.item>
            {{/if}}

            {{#if
              (and this.details.can_archive_topic (not this.isPrivateMessage))
            }}
              <dropdown.item class="topic-admin-archive">
                <DButton
                  @label={{if
                    this.archived
                    "topic.actions.unarchive"
                    "topic.actions.archive"
                  }}
                  @action={{fn this.onButtonAction "toggleArchived"}}
                  @icon="folder"
                />
              </dropdown.item>
            {{/if}}

            {{#if this.details.can_toggle_topic_visibility}}
              <dropdown.item class="topic-admin-visible">
                <DButton
                  @label={{if
                    this.visible
                    "topic.actions.invisible"
                    "topic.actions.visible"
                  }}
                  @action={{fn this.onButtonAction "toggleVisibility"}}
                  @icon={{if this.visible "far-eye-slash" "far-eye"}}
                />
              </dropdown.item>
            {{/if}}

            {{#if (and this.details.can_convert_topic)}}
              <dropdown.item class="topic-admin-convert">
                <DButton
                  @label={{if
                    this.isPrivateMessage
                    "topic.actions.make_public"
                    "topic.actions.make_private"
                  }}
                  @action={{fn
                    this.onButtonAction
                    (if
                      this.isPrivateMessage
                      "convertToPublicTopic"
                      "convertToPrivateMessage"
                    )
                  }}
                  @icon={{if this.isPrivateMessage "comment" "envelope"}}
                />
              </dropdown.item>
            {{/if}}

            {{#if this.showTopicManagementSection}}
              {{#if this.showTopicManagementSectionDivider}}
                <dropdown.divider />
              {{/if}}

              {{#if this.showTopicTimerItem}}
                <dropdown.item class="admin-topic-timer-update">
                  <DButton
                    @label="topic.actions.timed_update"
                    @action={{fn this.onButtonAction "showTopicTimerModal"}}
                    @icon="far-clock"
                  />
                </dropdown.item>
              {{/if}}

              {{#if this.currentUser.canManageTopic}}
                {{#if this.currentUser.staff}}
                  <dropdown.item class="topic-admin-change-timestamp">
                    <DButton
                      @label="topic.change_timestamp.title"
                      @action={{fn this.onButtonAction "showChangeTimestamp"}}
                      @icon="calendar-days"
                    />
                  </dropdown.item>
                {{/if}}

                <dropdown.item class="topic-admin-reset-bump-date">
                  <DButton
                    @label="topic.actions.reset_bump_date"
                    @action={{fn this.onButtonAction "resetBumpDate"}}
                    @icon="anchor"
                  />
                </dropdown.item>

                <dropdown.item class="topic-admin-slow-mode">
                  <DButton
                    @label="topic.actions.slow_mode"
                    @action={{fn this.onButtonAction "showTopicSlowModeUpdate"}}
                    @icon="hourglass-start"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}

            {{#if
              (or
                this.currentUser.staff
                this.showNestedRepliesToggle
                this.extraButtons.length
              )
            }}
              <dropdown.divider />

              {{#if this.currentUser.staff}}
                <dropdown.item class="topic-admin-moderation-history">
                  <DButton
                    @label="review.moderation_history"
                    @href={{this.topicModerationHistoryUrl}}
                    @icon="list"
                  />
                </dropdown.item>
              {{/if}}

              {{#if this.showNestedRepliesToggle}}
                <dropdown.item class="topic-admin-nested-replies">
                  <DButton
                    @label={{this.nestedRepliesToggleLabel}}
                    @action={{this.toggleNestedReplies}}
                    @icon="nested-thread"
                  />
                </dropdown.item>
              {{/if}}

              {{#each this.extraButtonGroups as |group index|}}
                {{#if group.label}}
                  {{#if
                    (or
                      this.currentUser.staff this.showNestedRepliesToggle index
                    )
                  }}
                    <dropdown.divider />
                  {{/if}}
                  <dropdown.subheader>{{group.label}}</dropdown.subheader>
                {{/if}}

                {{#each group.buttons as |button|}}
                  <dropdown.item>
                    <DButton
                      @label={{button.label}}
                      @translatedLabel={{button.translatedLabel}}
                      @icon={{button.icon}}
                      class={{dConcatClass "btn-transparent" button.className}}
                      @action={{fn this.onExtraButtonAction button.action}}
                    />
                  </dropdown.item>
                {{/each}}
              {{/each}}
            {{/if}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
