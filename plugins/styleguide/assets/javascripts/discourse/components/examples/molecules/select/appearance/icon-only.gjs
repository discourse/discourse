import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

export default class IconOnlySelectExample extends Component {
  @tracked value = "left";

  get items() {
    return [
      {
        id: "left",
        icon: "align-left",
        name: i18n("styleguide.sections.select.icon_only_align_left"),
      },
      {
        id: "center",
        icon: "align-center",
        name: i18n("styleguide.sections.select.icon_only_align_center"),
      },
      {
        id: "right",
        icon: "align-right",
        name: i18n("styleguide.sections.select.icon_only_align_right"),
      },
    ];
  }

  get icon() {
    return this.items.find((item) => item.id === this.value)?.icon;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <div class="select-examples__alignment">
      <DSelect
        @ariaLabel={{i18n "styleguide.sections.select.icon_only_label"}}
        @icon={{this.icon}}
        @iconOnly={{true}}
        @identifier="sg-icon-only"
        @items={{this.items}}
        @onChange={{this.onChange}}
        @value={{this.value}}
        @variant="static"
      >
        <:item as |alignment|>
          <span class="select-examples__row select-examples__row--glyph">
            {{dIcon alignment.icon}}
            <span class="select-examples__primary">{{alignment.name}}</span>
          </span>
        </:item>
      </DSelect>
      <p
        class="select-examples__aligned --{{this.value}}"
        data-alignment={{this.value}}
      >
        {{~i18n "styleguide.sections.select.icon_only_sample"~}}
      </p>
    </div>
  </template>
}
