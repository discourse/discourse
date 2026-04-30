import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { ICONS } from "discourse/components/post/small-action";
import UserAvatar from "discourse/components/user-avatar";
import icon from "discourse/helpers/d-icon";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const ACTIVITY_LOG_ICONS = {
  topic_created: "plus",
};

export default class NestedActivityLogItem extends Component {
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
    <li class="nested-activity-log-modal__item">
      <span class="nested-activity-log-modal__icon" aria-hidden="true">
        {{icon this.iconName}}
      </span>
      <div class="nested-activity-log-modal__content">
        <div class="nested-activity-log-modal__desc">
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
          <div class="nested-activity-log-modal__message">
            {{trustHTML @action.cooked}}
          </div>
        {{/if}}
      </div>
    </li>
  </template>
}
