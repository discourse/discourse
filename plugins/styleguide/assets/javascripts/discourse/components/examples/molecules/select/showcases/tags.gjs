import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures.js";

export default class TagsSelectExample extends Component {
  @tracked items = TAGS;
  @tracked
  value = [
    "design-system",
    "accessibility",
    "performance",
    "onboarding",
    "theming",
    "migrations",
  ];

  @action
  allowCreate(filter, items) {
    const slug = this.#slug(filter);
    return (
      slug.length > 0 && !items.some((item) => item.slug.toLowerCase() === slug)
    );
  }

  @action
  createOption(filter) {
    const label = filter.trim();
    return { isNew: true, label, slug: this.#slug(label) };
  }

  @action
  source() {
    return this.items;
  }

  @action
  update(value, records) {
    this.value = value;
    const created = records.filter(
      (record) => record.isNew && !this.items.includes(record)
    );
    if (created.length > 0) {
      this.items = [...this.items, ...created];
    }
  }

  #slug(label) {
    return label
      .trim()
      .toLowerCase()
      .replaceAll(/[^a-z0-9]+/g, "-")
      .replaceAll(/(^-|-$)/g, "");
  }

  <template>
    <DSelect
      @allowCreate={{this.allowCreate}}
      @clearable={{true}}
      @createOption={{this.createOption}}
      @identifier="sg-tags"
      @labelField="label"
      @multiple={{true}}
      @onChange={{this.update}}
      @options={{this.source}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.showcases.tags.placeholder"
        )
        searchPlaceholder=(i18n
          "styleguide.sections.select.showcases.tags.search_placeholder"
        )
      }}
      @value={{this.value}}
      @valueField="slug"
      @variant="button"
    >
      <:option as |tag config option|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon (if option.create "plus" "tag")}}
          <span class="select-examples__primary">
            {{#if option.create}}
              {{i18n
                "styleguide.sections.select.showcases.tags.create"
                tag=tag.label
              }}
            {{else}}
              {{tag.label}}
            {{/if}}
          </span>
          {{#unless option.create}}
            <span class="select-examples__meta">{{tag.count}}</span>
          {{/unless}}
        </span>
      </:option>
    </DSelect>
  </template>
}
