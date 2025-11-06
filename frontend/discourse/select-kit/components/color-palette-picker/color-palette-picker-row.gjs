import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ColorPalettePreview from "discourse/components/color-palette-preview";
import { i18n } from "discourse-i18n";
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
        {{i18n "user.color_schemes.picker.active"}}
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
