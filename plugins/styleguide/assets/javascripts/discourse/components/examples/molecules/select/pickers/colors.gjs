import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DSelect from "discourse/ui-kit/select/d-select";

export default class ColorsSelectExample extends Component {
  @tracked value = "midnight";

  items = [
    {
      id: "glacier",
      name: "Glacier",
      colors: ["F7FBFF", "DDEBF7", "17324D", "2F80ED", "FF6B5E"],
    },
    {
      id: "midnight",
      name: "Midnight",
      colors: ["0B1020", "202A44", "F1F5F9", "38BDF8", "A78BFA"],
    },
    {
      id: "moss",
      name: "Moss",
      colors: ["F3F1E7", "D9E2CF", "26382D", "4F7C59", "C9843D"],
    },
    {
      id: "ember",
      name: "Ember",
      colors: ["211613", "3B211B", "FBE9DA", "E45D38", "F2B84B"],
    },
    {
      id: "sandstone",
      name: "Sandstone",
      colors: ["FFF4DF", "E8CFAF", "49362B", "B75D3E", "2F7F7A"],
    },
    {
      id: "lagoon",
      name: "Lagoon",
      colors: ["E8FAF8", "B9E5DF", "123B42", "008C8C", "FF7A59"],
    },
    {
      id: "orchid",
      name: "Orchid",
      colors: ["F9EFF7", "E8CBE1", "47243D", "A64D79", "6C63C7"],
    },
    {
      id: "high-contrast",
      name: "High contrast",
      colors: ["FFFFFF", "E6E6E6", "000000", "005FCC", "D50000"],
    },
  ].map((scheme) => ({
    ...scheme,
    swatches: scheme.colors.map((color) =>
      trustHTML(`--swatch-color: #${color}`)
    ),
  }));

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-colors"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @variant="button"
    >
      <:selection as |scheme|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-showcases__swatches" aria-hidden="true">
            {{#each scheme.swatches key="@index" as |swatch|}}
              <span class="select-showcases__swatch" style={{swatch}}></span>
            {{/each}}
          </span>
          {{scheme.name}}
        </span>
      </:selection>

      <:item as |scheme|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-showcases__swatches" aria-hidden="true">
            {{#each scheme.swatches key="@index" as |swatch|}}
              <span class="select-showcases__swatch" style={{swatch}}></span>
            {{/each}}
          </span>
          <span class="select-examples__primary">{{scheme.name}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
