import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay, PEOPLE } from "../../../../../lib/select-fixtures";

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
    class="btn-transparent"
    @action={{@state.close}}
    @icon="arrow-up-right-from-square"
    @label="styleguide.sections.select.content.footer_view_all"
  />
</template>;

export default class FooterSelectExample extends Component {
  @tracked value = null;

  get load() {
    if (this.args.state === "empty") {
      return this.loadEmpty;
    }
    if (this.args.state === "error") {
      return this.loadBroken;
    }
    return this.loadPeople;
  }

  @action
  async loadPeople(filter, { signal }) {
    await delay(signal, 400);
    return PEOPLE.filter((person) =>
      person.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  async loadEmpty(_filter, { signal }) {
    await delay(signal, 400);
    return [];
  }

  @action
  async loadBroken(_filter, { signal }) {
    await delay(signal, 400);
    throw new Error("The source could not be reached.");
  }

  @action
  resolveValue(value) {
    return PEOPLE.find((person) => person.id === value);
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @load={{this.load}}
      @resolveValue={{this.resolveValue}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @labelField="name"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    >
      <:footer as |state|><FooterContents @state={{state}} /></:footer>
    </DSelect>
  </template>
}
