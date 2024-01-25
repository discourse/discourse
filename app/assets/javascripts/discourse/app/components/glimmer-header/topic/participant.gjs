import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import icon from "discourse-common/helpers/d-icon";
import eq from "truth-helpers/helpers/eq";
import { on } from "@ember/modifier";
import { hash } from "@ember/helper";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import { htmlSafe } from "@ember/template";

export default class Participant extends Component {
  @service appEvents;

  get url() {
    if (this.args.type === "user") {
      return this.args.user.path;
    } else {
      return getURL(`/g/${this.args.group.name}`);
    }
  }

  get typeClass() {
    return `trigger-${this.args.type}-card`;
  }

  get avatarImage() {
    if (!this.args.user) {
      return;
    }

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
        title={{@user.username}}
      >
        {{#if (eq @type "user")}}
          {{this.avatarImage}}
        {{else}}
          <span>
            {{icon "users"}}
            {{@group.name}}
          </span>
        {{/if}}
      </a>
    </span>
  </template>
}
