import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures.js";

export default class TopicGlyphSelectExample extends Component {
  @tracked value = null;

  items = TAGS.map((tag) => ({
    ...tag,
    usesLabel: i18n("styleguide.sections.select.content.glyph_uses", {
      count: tag.count,
      formatted: new Intl.NumberFormat().format(tag.count),
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
      @labelField="label"
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.content.glyph_placeholder"
        )
      }}
      @value={{this.value}}
      @valueField="slug"
    >
      <:item as |tag|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon "tag"}}
          <span class="select-examples__primary">{{tag.label}}</span>
          <span class="select-examples__meta">{{tag.usesLabel}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
