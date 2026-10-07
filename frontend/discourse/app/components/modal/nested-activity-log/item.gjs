import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import {
  customGroupActionCodes,
  default as PostSmallAction,
  GROUP_ACTION_CODES,
} from "discourse/components/post/small-action";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { groupPath, userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

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
    return `<a class="mention-group" href="${groupPath(encodeURIComponent(who))}">@${escaped}</a>`;
  }
  return `<a class="mention" href="${userPath(encodeURIComponent(who))}">@${escaped}</a>`;
}

export default class NestedActivityLogItem extends Component {
  get isSynthetic() {
    return this.args.action.synthetic;
  }

  get description() {
    return buildDescription(this.args.action, this.args.topicId);
  }

  get user() {
    if (!this.args.action.username) {
      return null;
    }
    return {
      id: this.args.action.user_id,
      username: this.args.action.username,
      avatar_template: this.args.action.avatar_template,
    };
  }

  <template>
    <li
      class={{dConcatClass
        "nested-activity-log-modal__item"
        (if this.isSynthetic "--synthetic")
      }}
    >
      {{#if this.isSynthetic}}
        <span aria-hidden="true" class="nested-activity-log-modal__icon">
          {{dIcon "plus"}}
        </span>
        <div class="nested-activity-log-modal__content">
          <div class="nested-activity-log-modal__desc">
            {{#if this.user}}
              <DUserAvatar
                @ariaHidden={{false}}
                @size="small"
                @user={{this.user}}
              />
            {{/if}}
            <span>{{this.description}}</span>
          </div>
        </div>
      {{else}}
        <PostSmallAction
          class="nested-activity-log-modal__post"
          @deletePost={{fn @deletePost @action}}
          @editPost={{fn @editPost @action}}
          @elementId="nested-activity-log-post-{{@action.id}}"
          @post={{@action}}
          @recoverPost={{fn @recoverPost @action}}
        />
      {{/if}}
    </li>
  </template>
}
