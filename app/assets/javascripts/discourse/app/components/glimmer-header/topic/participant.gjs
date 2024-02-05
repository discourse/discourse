import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse-common/helpers/d-icon";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import getURL from "discourse-common/lib/get-url";
import eq from "truth-helpers/helpers/eq";

export default class Participant extends Component {
  @service appEvents;

  get url() {
    return this.args.type === "user"
      ? this.args.user.path
      : getURL(`/g/${this.args.username}`);
  }

  get typeClass() {
    return `trigger-${this.args.type}-card`;
  }

  get avatarImage() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.user.avatar_template,
        size: "tiny",
        title: this.args.username,
      })
    );
  }

  @action
  click(e) {
    this.appEvents.trigger(
      `topic-header:trigger-${this.args.type}-card`,
      this.args.username,
      e.target
    );
    e.preventDefault();
  }

  <template>
    <span class={{this.typeClass}}>
      <a
        class="icon"
        {{on "click" this.click}}
        href={{this.url}}
        data-auto-route="true"
        title={{@username}}
      >
        {{#if (eq @type "user")}}
          {{this.avatarImage}}
        {{else}}
          <span>
            {{icon "users"}}
            {{@username}}
          </span>
        {{/if}}
      </a>
    </span>
  </template>
}
