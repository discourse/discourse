import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";

export default class Participant extends Component {
  @service appEvents;

  get url() {
    return this.args.type === "user"
      ? this.args.user.path
      : getURL(`/g/${this.args.username}`);
  }

  @action
  click(e) {
    this.appEvents.trigger(
      `topic-header:trigger-${this.args.type}-card`,
      this.args.username,
      e.target,
      e
    );
    e.preventDefault();
  }

  <template>
    <span class={{concat "trigger-" @type "-card"}}>
      <a
        class="icon"
        {{on "click" this.click}}
        href={{this.url}}
        data-auto-route="true"
        title={{@username}}
      >
        {{#if (eq @type "user")}}
          {{avatar @user.avatar_template "tiny" (hash title=@username)}}
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
