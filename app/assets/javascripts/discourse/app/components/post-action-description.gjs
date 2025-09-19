import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import {
  customGroupActionCodes,
  GROUP_ACTION_CODES,
} from "discourse/components/post/small-action";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export function actionDescriptionHtml(actionCode, createdAt, username, path) {
  const when = createdAt
    ? autoUpdatingRelativeAge(new Date(createdAt), {
        format: "medium-with-ago-and-on",
      })
    : "";

  let who = "";
  if (username) {
    if (
      GROUP_ACTION_CODES.includes(actionCode) ||
      customGroupActionCodes.includes(actionCode)
    ) {
      who = `<a class="mention-group" href="/g/${username}">@${username}</a>`;
    } else {
      who = `<a class="mention" href="${userPath(username)}">@${username}</a>`;
    }
  }
  return htmlSafe(i18n(`action_codes.${actionCode}`, { who, when, path }));
}

export default class PostActionDescription extends Component {
  get description() {
    if (this.args.actionCode) {
      return actionDescriptionHtml(
        this.args.actionCode,
        this.args.createdAt,
        this.args.username,
        this.args.path
      );
    }
  }

  <template>
    {{#if this.description}}
      <p class="excerpt">{{this.description}}</p>
    {{/if}}
  </template>
}
