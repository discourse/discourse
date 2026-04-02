import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DModal from "discourse/components/d-modal";
import { ICONS } from "discourse/components/post/small-action";
import UserAvatar from "discourse/components/user-avatar";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class NestedActivityLog extends Component {
  @tracked loading = true;
  @tracked smallActions = [];

  constructor() {
    super(...arguments);
    this.fetchActivity();
  }

  @action
  async fetchActivity() {
    try {
      const topic = this.args.model.topic;
      const data = await ajax(`/n/${topic.slug}/${topic.id}/activity.json`);
      this.smallActions = data.small_actions || [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "nested_replies.activity_log.title"}}
      @closeModal={{@closeModal}}
      class="nested-activity-log-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.smallActions.length}}
            <ul class="nested-activity-log__list">
              {{#each this.smallActions as |sa|}}
                <ActivityLogItem @action={{sa}} @topicId={{@model.topic.id}} />
              {{/each}}
            </ul>
          {{else}}
            <p class="nested-activity-log__empty">
              {{i18n "nested_replies.activity_log.empty"}}
            </p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}

const ACTIVITY_LOG_ICONS = {
  topic_created: "plus",
};

class ActivityLogItem extends Component {
  get iconName() {
    const code = this.args.action.action_code;
    return ACTIVITY_LOG_ICONS[code] || ICONS[code] || "exclamation";
  }

  get description() {
    const sa = this.args.action;
    const when = autoUpdatingRelativeAge(new Date(sa.created_at), {
      format: "medium-with-ago-and-on",
    });

    let who = "";
    if (sa.action_code_who) {
      const escaped = escapeExpression(sa.action_code_who);
      who = `<a class="mention" href="${userPath(sa.action_code_who)}">@${escaped}</a>`;
    }

    const path = getURL(sa.action_code_path || `/t/${this.args.topicId}`);

    return trustHTML(
      i18n(`action_codes.${sa.action_code}`, { who, when, path })
    );
  }

  get user() {
    if (!this.args.action.username) {
      return null;
    }
    return {
      username: this.args.action.username,
      avatar_template: this.args.action.avatar_template,
    };
  }

  <template>
    <li class="nested-activity-log__item">
      <span class="nested-activity-log__icon">
        {{icon this.iconName}}
      </span>
      <div class="nested-activity-log__content">
        <div class="nested-activity-log__desc">
          {{#if this.user}}
            <UserAvatar
              @ariaHidden={{true}}
              @size="small"
              @user={{this.user}}
            />
          {{/if}}
          <span>{{this.description}}</span>
        </div>
        {{#if @action.cooked}}
          <div class="nested-activity-log__message">
            {{trustHTML @action.cooked}}
          </div>
        {{/if}}
      </div>
    </li>
  </template>
}
