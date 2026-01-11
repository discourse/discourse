import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { getTypeIcon, getValueType } from "../lib/get-value-type";
import { highlightText } from "../lib/highlight-text";
import CopyButton from "./copy-button";

export default class InspectorKey extends Component {
  get decoratedValue() {
    return highlightText(this.args.value, this.args.filter);
  }

  get valueType() {
    return this.args.valueData !== undefined
      ? getValueType(this.args.valueData)
      : null;
  }

  get typeIcon() {
    return this.valueType ? getTypeIcon(this.valueType) : null;
  }

  <template>
    <div
      class={{concatClass
        "inspector-key"
        (if @freeform "--freeform")
        (if @hoverable "inspector-data-table__hoverable-cell")
        (if this.valueType (concat "--type-" this.valueType))
      }}
    >
      {{#if this.typeIcon}}
        <span class="inspector-key__icon">
          {{icon this.typeIcon}}
        </span>
      {{/if}}
      <span class="inspector-key__text">{{this.decoratedValue}}</span>
      <div class="inspector-key__actions">
        {{#if @copyable}}
          <CopyButton @value={{@value}} @alwaysVisible={{@alwaysVisibleCopy}} />
        {{/if}}
      </div>
    </div>
  </template>
}
