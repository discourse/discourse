import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay, LOCALES, TAGS } from "../../../../../lib/select-fixtures.js";

export default class AsyncUpdateSelectExample extends Component {
  @tracked value = LOCALES[0].id;
  @tracked tags = [];

  get items() {
    return [
      {
        id: "suggest",
        name: i18n("styleguide.sections.select.async_update_suggest"),
        onSelect: this.suggest,
      },
      {
        id: "validate",
        name: i18n("styleguide.sections.select.async_update_clear"),
        onSelect: this.clearIfInvalid,
      },
      ...LOCALES,
    ];
  }

  get tagItems() {
    return [
      {
        slug: "suggest",
        label: i18n("styleguide.sections.select.async_update_suggest_tags"),
        onSelect: this.suggestTags,
      },
      ...TAGS,
    ];
  }

  @action
  clearIfInvalid(control) {
    this.#update(control, (scope) => scope.clear());
  }

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  onTagsChange(value) {
    this.tags = value;
  }

  @action
  suggest(control) {
    this.#update(control, (scope) => scope.select(LOCALES[1]));
  }

  @action
  suggestTags(control) {
    this.#update(control, (scope) => {
      scope.select(TAGS[0]);
      scope.select(TAGS[1]);
    });
  }

  #update(control, apply) {
    control
      .update(async (scope) => {
        control.close();
        await delay(undefined, 1500);
        apply(scope);
      })
      .catch(popupAjaxError);
  }

  <template>
    <div class="select-examples__pair">
      <div class="select-examples__pair-item">
        <DSelect
          @identifier="sg-async-update"
          @items={{this.items}}
          @label={{i18n "styleguide.sections.select.async_update_single_label"}}
          @onChange={{this.onChange}}
          @placeholder={{i18n
            "styleguide.sections.select.placeholders.choose_language"
          }}
          @value={{this.value}}
        />
      </div>
      <div class="select-examples__pair-item">
        <DSelect
          @identifier="sg-async-update-tags"
          @items={{this.tagItems}}
          @label={{i18n "styleguide.sections.select.async_update_multi_label"}}
          @labelField="label"
          @multiple={{true}}
          @onChange={{this.onTagsChange}}
          @placeholder={{i18n
            "styleguide.sections.select.placeholders.choose_tags"
          }}
          @value={{this.tags}}
          @valueField="slug"
        />
      </div>
    </div>
  </template>
}
