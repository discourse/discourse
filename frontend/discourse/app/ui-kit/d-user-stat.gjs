import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import formatDuration from "discourse/ui-kit/helpers/d-format-duration";
import icon from "discourse/ui-kit/helpers/d-icon";
import number from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class UserStat extends Component {
  get type() {
    return this.args.type ?? "number";
  }

  get isNumber() {
    return this.type === "number";
  }

  get isDuration() {
    return this.type === "duration";
  }

  <template>
    <div class="user-stat">
      <span class="value" title={{@rawTitle}}>
        {{#if this.isNumber}}
          {{number @value}}
        {{else if this.isDuration}}
          {{formatDuration @value}}
        {{else}}
          {{@value}}
        {{/if}}
      </span>
      <span class="label">
        {{#if @icon}}{{icon @icon}}{{/if}}
        {{trustHTML (i18n @label count=@value)}}
      </span>
    </div>
  </template>
}
