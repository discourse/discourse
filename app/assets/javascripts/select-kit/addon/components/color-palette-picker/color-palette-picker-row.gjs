import { classNames } from "@ember-decorators/component";
import ColorPalettePreview from "discourse/components/color-palette-preview";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("color-palette-picker-row")
export default class ColorPalettePickerRow extends SelectKitRowComponent {
  <template>
    <ColorPalettePreview class="preview" @scheme={{@item}} />
    <div class="name">
      {{@item.name}}
    </div>
  </template>
}
