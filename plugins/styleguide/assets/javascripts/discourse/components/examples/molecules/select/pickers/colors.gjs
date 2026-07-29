import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DSelect from "discourse/ui-kit/select/d-select";
import { COLOR_SCHEMES } from "../../../../../lib/select-fixtures";

export default class ColorsSelectExample extends Component {
  @tracked value = "dark";

  items = COLOR_SCHEMES.map((scheme) => ({
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
