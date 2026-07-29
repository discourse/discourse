import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { PEOPLE } from "../../../../../lib/select-fixtures";

export default class SelectionBlockSelectExample extends Component {
  @tracked value = this.args.multiple ? [101, 103] : 101;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @items={{PEOPLE}}
      @multiple={{@multiple}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @labelField="name"
      @placeholder={{i18n
        (if
          @multiple
          "styleguide.sections.select.multi_placeholder"
          "styleguide.sections.select.placeholder"
        )
      }}
    >
      <:item as |person|>
        <span class="select-examples__row select-examples__row--identity">
          <img class="select-examples__avatar" src={{person.avatar}} alt="" />
          <span class="select-examples__details">
            <span class="select-examples__primary">{{person.name}}</span>
            <span class="select-examples__secondary">
              {{if person.title person.title (concat "@" person.username)}}
            </span>
          </span>
        </span>
      </:item>
      <:selection as |person|>
        <span class="select-examples__row select-examples__row--glyph">
          <img
            class="select-examples__avatar --small"
            src={{person.avatar}}
            alt=""
          />
          {{person.name}}
        </span>
      </:selection>
    </DSelect>
  </template>
}
