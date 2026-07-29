import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures";

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
  createItem(filter) {
    const label = filter.trim();
    return { __create: true, label, slug: this.#slug(label) };
  }

  @action
  source() {
    return this.items;
  }

  @action
  update(value, items) {
    this.value = value;
    const createdItems = items.filter(
      (item) => item.__create && !this.items.includes(item)
    );
    if (createdItems.length > 0) {
      this.items = [...this.items, ...createdItems];
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
      @identifier="sg-tags"
      @items={{this.source}}
      @value={{this.value}}
      @onChange={{this.update}}
      @multiple={{true}}
      @variant="button"
      @valueField="slug"
      @labelField="label"
      @allowCreate={{this.allowCreate}}
      @createItem={{this.createItem}}
      @clearable={{true}}
      @placeholder={{i18n
        "styleguide.sections.select.pickers.tags.placeholder"
      }}
      @searchPlaceholder={{i18n
        "styleguide.sections.select.pickers.tags.search_placeholder"
      }}
    >
      <:item as |tag|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon (if tag.__create "plus" "tag")}}
          <span class="select-examples__primary">
            {{#if tag.__create}}
              {{i18n
                "styleguide.sections.select.pickers.tags.create"
                tag=tag.label
              }}
            {{else}}
              {{tag.label}}
            {{/if}}
          </span>
          {{#unless tag.__create}}
            <span class="select-examples__meta">{{tag.count}}</span>
          {{/unless}}
        </span>
      </:item>
    </DSelect>
  </template>
}
