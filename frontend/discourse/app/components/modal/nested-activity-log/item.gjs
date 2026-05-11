import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  customGroupActionCodes,
  GROUP_ACTION_CODES,
  ICONS,
} from "discourse/components/post/small-action";
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

// `action_codes.*` translations interpolate %{who}/%{when}/%{path} at arbitrary
// positions inside a translated sentence, so the substitutions have to be HTML
// strings — there's no template-only equivalent. Mirrors small-action.gjs.
function buildDescription(action, topicId) {
  const code = action.action_code;
  const when = autoUpdatingRelativeAge(new Date(action.created_at), {
    format: "medium-with-ago-and-on",
  });
  const path = getURL(action.action_code_path || `/t/${topicId}`);
  const who = mentionLinkFor(code, action.action_code_who);

  return trustHTML(i18n(`action_codes.${code}`, { who, when, path }));
}

function mentionLinkFor(code, who) {
  if (!who) {
    return "";
  }

  const escaped = escapeExpression(who);
  if (
    GROUP_ACTION_CODES.includes(code) ||
    customGroupActionCodes.includes(code)
  ) {
    return `<a class="mention-group" href="/g/${encodeURIComponent(who)}">@${escaped}</a>`;
  }
  return `<a class="mention" href="${userPath(who)}">@${escaped}</a>`;
}

export default class NestedActivityLogItem extends Component {
  get iconName() {
    const code = this.args.action.action_code;
    return ACTIVITY_LOG_ICONS[code] || ICONS[code] || "exclamation";
  }

  get description() {
    return buildDescription(this.args.action, this.args.topicId);
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
