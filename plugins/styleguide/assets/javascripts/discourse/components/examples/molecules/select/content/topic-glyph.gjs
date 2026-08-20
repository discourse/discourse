import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { topics } from "../../../../../lib/select-fixtures";

export default class TopicGlyphSelectExample extends Component {
  @tracked value = null;

  items = topics()
    .slice(0, 40)
    .map((topic) => ({
      ...topic,
      categoryColor: trustHTML(`--bullet-color: #${topic.category.color}`),
      repliesLabel: i18n("styleguide.sections.select.content.glyph_replies", {
        count: topic.replies,
      }),
    }));

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-glyph"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.content.glyph_placeholder"
      }}
    >
      <:item as |topic|>
        <span class="select-examples__row select-examples__row--glyph">
          <span
            class="select-examples__bullet"
            style={{topic.categoryColor}}
            aria-hidden="true"
          ></span>
          <span class="select-examples__primary">{{topic.name}}</span>
          <span class="select-examples__meta">{{topic.repliesLabel}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
