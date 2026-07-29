import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { localeApi } from "../../../../../lib/select-fixtures";

export default class DebounceSelectExample extends Component {
  @tracked value = null;
  @tracked keystrokes = 0;
  @tracked queries = [];

  #sequence = 0;

  @action
  async load(filter, options) {
    const items = await localeApi.search(filter, options);
    this.queries = [
      ...this.queries,
      { id: (this.#sequence += 1), query: filter },
    ];
    return items;
  }

  @action
  countKeystroke() {
    this.keystrokes++;
  }

  @action
  resetLog() {
    this.keystrokes = 0;
    this.queries = [];
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-debounce"
      @placement="top-start"
      @load={{this.load}}
      @resolveValue={{localeApi.find}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @onShow={{this.resetLog}}
      @variant="button"
      @debounce={{300}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      {{on "input" this.countKeystroke}}
    />
    <output class="styleguide-example__result">
      {{i18n
        "styleguide.sections.select.debounce_result"
        keystrokes=this.keystrokes
        requests=this.queries.length
      }}
      {{#if this.queries}}
        <ol class="select-examples__query-log">
          {{#each this.queries key="id" as |entry|}}
            <li>&ldquo;{{entry.query}}&rdquo;</li>
          {{/each}}
        </ol>
      {{/if}}
    </output>
  </template>
}
