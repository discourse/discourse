import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class DUserStat extends Component {
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
          {{dNumber @value}}
        {{else if this.isDuration}}
          {{dFormatDuration @value}}
        {{else}}
          {{@value}}
        {{/if}}
      </span>
      <span class="label">
        {{#if @icon}}{{dIcon @icon}}{{/if}}
        {{trustHTML (i18n @label count=@value)}}
      </span>
    </div>
  </template>
}
