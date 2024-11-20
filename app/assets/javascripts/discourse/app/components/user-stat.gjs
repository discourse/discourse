import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import formatDuration from "discourse/helpers/format-duration";
import number from "discourse/helpers/number";
import icon from "discourse-common/helpers/d-icon";
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
        {{htmlSafe (i18n @label count=@value)}}
      </span>
    </div>
  </template>
}
