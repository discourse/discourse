import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import DMenu from "float-kit/components/d-menu";

export default class TopicAdminMenu extends Component {
  @service adminTopicMenuButtons;
  @service currentUser;

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
      this.details?.can_archive_topic ||
      this.details?.can_close_topic ||
      this.details?.can_split_merge_topic
    );
  }

  <template>
    {{#if this.showAdminButton}}
      <DMenu
        @identifier="topic-admin-menu"
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @autofocus={{true}}
        @triggerClass="btn-default btn-icon toggle-admin-menu"
      >
        <:trigger>
          {{icon "wrench"}}
        </:trigger>
        <:content>
          <DropdownMenu as |dropdown|>
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
                    class="popup-menu-btn-danger btn-danger"
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
                  @icon={{if @topic.closed "unlock" "lock"}}
                />
              </dropdown.item>
            {{/if}}

            {{#if
              (and
                this.details.can_pin_unpin_topic
                (not this.isPrivateMessage)
                (or this.visible this.featured)
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

            <dropdown.divider />

            {{#if this.currentUser.canManageTopic}}
              <dropdown.item class="admin-topic-timer-update">
                <DButton
                  @label="topic.actions.timed_update"
                  @action={{fn this.onButtonAction "showTopicTimerModal"}}
                  @icon="far-clock"
                />
              </dropdown.item>

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

            {{#if (or this.currentUser.staff this.extraButtons.length)}}
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

              {{#each this.extraButtons as |button|}}
                <dropdown.item>
                  <DButton
                    @label={{button.label}}
                    @translatedLabel={{button.translatedLabel}}
                    @icon={{button.icon}}
                    class={{concatClass "btn-transparent" button.className}}
                    @action={{fn this.onExtraButtonAction button.action}}
                  />
                </dropdown.item>
              {{/each}}
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
