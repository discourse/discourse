import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures";

export default class StatusIconSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-status-icons"
      @items={{USER_GROUPS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @labelField="fullName"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    >
      <:item as |group|>
        <span class="select-examples__row">
          <span class="select-examples__primary">{{group.fullName}}</span>
          {{#if group.automatic}}
            <span class="select-examples__status">
              {{dIcon "gear"}}
              <span class="sr-only">
                {{i18n
                  "styleguide.sections.select.content.status_icon_automatic"
                }}
              </span>
            </span>
          {{/if}}
        </span>
      </:item>
    </DSelect>
  </template>
}
