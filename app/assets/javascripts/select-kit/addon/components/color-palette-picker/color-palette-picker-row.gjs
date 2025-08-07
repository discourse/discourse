import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ColorPalettePreview from "discourse/components/color-palette-preview";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("color-palette-picker-row")
export default class ColorPalettePickerRow extends SelectKitRowComponent {
  @computed("item.id", "value")
  get active() {
    return this.item?.id === this.value;
  }

  <template>
    {{#if this.active}}
      <span class="color-palette-picker-row__badge --active">
        {{! todo: use i18n (where should i put it?) }}
        Active
      </span>
    {{/if}}
    <ColorPalettePreview
      class="color-palette-picker-row__preview"
      @scheme={{@item}}
    />
    <div class="color-palette-picker-row__name">
      {{@item.name}}
    </div>
  </template>
}
