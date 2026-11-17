import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import SelectKitFilterComponent from "discourse/select-kit/components/select-kit/select-kit-filter";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("multi-select-filter")
export default class MultiSelectFilter extends SelectKitFilterComponent {
  @computed("placeholder", "selectKit.hasSelection")
  get computedPlaceholder() {
    if (this.hidePlaceholderWithSelection && this.selectKit?.hasSelection) {
      return "";
    }

    return isEmpty(this.placeholder) ? "" : this.placeholder;
  }

  @action
  onPaste(event) {
    const data = event?.clipboardData;

    if (!data) {
      return;
    }

    const parts = data.getData("text").split("|").filter(Boolean);

    if (parts.length > 1) {
      event.stopPropagation();
      event.preventDefault();

      this.selectKit.append(parts);

      return false;
    }
  }

  <template>
    {{#unless this.isHidden}}
      {{! filter-input-search prevents 1password from attempting autocomplete }}

      <Input
        autocapitalize="off"
        autocomplete="off"
        autocorrect="off"
        class="filter-input"
        name="filter-input-search"
        placeholder={{this.computedPlaceholder}}
        spellcheck={{false}}
        tabindex={{0}}
        @type="search"
        @value={{readonly this.selectKit.filter}}
        {{on "paste" this.onPaste}}
        {{on "keydown" this.onKeydown}}
        {{on "keyup" this.onKeyup}}
        {{on "input" this.onInput}}
      />

      {{#if this.selectKit.options.filterIcon}}
        {{dIcon this.selectKit.options.filterIcon class="filter-icon"}}
      {{/if}}
    {{/unless}}
  </template>
}
