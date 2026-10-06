import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  emptyApi,
  peopleApi,
  unavailableApi,
} from "../../../../../lib/select-fixtures";

const FooterContents = <template>
  {{#if @state.loadedCount}}
    <span class="select-examples__footer-count">
      {{i18n
        "styleguide.sections.select.content.footer_count"
        count=@state.loadedCount
      }}
    </span>
  {{else}}
    <span class="select-examples__footer-count">
      {{i18n "styleguide.sections.select.content.footer_nothing"}}
    </span>
  {{/if}}
  <DButton
    class="btn-flat"
    @action={{@state.close}}
    @icon="up-right-from-square"
    @label="styleguide.sections.select.content.footer_view_all"
  />
</template>;

export default class FooterSelectExample extends Component {
  @tracked value = null;

  get api() {
    if (this.args.state === "empty") {
      return emptyApi;
    }
    if (this.args.state === "error") {
      return unavailableApi;
    }
    return peopleApi;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @labelField="name"
      @load={{this.api.search}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @resolveValue={{this.api.find}}
      @value={{this.value}}
    >
      <:footer as |state|><FooterContents @state={{state}} /></:footer>
    </DSelect>
  </template>
}
