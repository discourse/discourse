import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { PEOPLE } from "../../../../../lib/select-fixtures.js";

export default class StatusIconSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-status-icons"
      @items={{PEOPLE}}
      @labelField="name"
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.message_someone"
        )
      }}
      @value={{this.value}}
    >
      <:item as |person|>
        <span class="select-examples__row">
          <span class="select-examples__primary">{{person.name}}</span>
          {{#if person.status}}
            <span class="select-examples__status">
              {{dIcon "circle-info"}}
              <span class="sr-only">{{person.status}}</span>
            </span>
          {{/if}}
        </span>
      </:item>
    </DSelect>
  </template>
}
