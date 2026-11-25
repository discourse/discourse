import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const KINDS = {
  self: { icon: "lock", label: "user.self_only_setting" },
  staff: { icon: "shield-halved", label: "user.staff_only_setting" },
};

export default class AccessNotice extends Component {
  get shown() {
    if (this.args.kind === "self") {
      return !this.args.user.isCurrent;
    }

    return !!this.args.user.staff_only_settings?.includes(this.args.setting);
  }

  get disabled() {
    return this.args.kind === "self" && this.shown;
  }

  get kind() {
    return KINDS[this.args.kind];
  }

  <template>
    {{#if this.shown}}
      <p class="access-notice --{{@kind}}">
        {{dIcon this.kind.icon}}
        <span>{{i18n this.kind.label username=@user.username}}</span>
      </p>
    {{/if}}
    {{yield this.disabled}}
  </template>
}
