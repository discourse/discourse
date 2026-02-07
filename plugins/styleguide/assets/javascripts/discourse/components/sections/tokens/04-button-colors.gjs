import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import ColorExample from "discourse/plugins/styleguide/discourse/components/color-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class ButtonColors extends Component {
  get buttonTypes() {
    return [
      {
        name: "default",
        class: "btn-default",
        prefix: "d-button-default",
      },
      {
        name: "primary",
        class: "btn-primary",
        prefix: "d-button-primary",
      },
      {
        name: "danger",
        class: "btn-danger",
        prefix: "d-button-danger",
      },
      {
        name: "success",
        class: "btn-success",
        prefix: "d-button-success",
      },
      {
        name: "flat",
        class: "btn-flat",
        prefix: "d-button-flat",
      },
      {
        name: "transparent",
        class: "btn-transparent",
        prefix: "d-button-transparent",
      },
    ];
  }

  <template>
    {{#each this.buttonTypes as |btnType|}}
      <StyleguideExample @title={{btnType.name}}>
        <div class="button-colors-row">
          <div class="button-colors-preview">
            <DButton
              @translatedLabel={{btnType.name}}
              class={{btnType.class}}
            />
          </div>
          <div class="color-row button-colors-swatches">
            <ColorExample @color="{{btnType.prefix}}-text-color" />
            <ColorExample @color="{{btnType.prefix}}-bg-color" />
            <ColorExample @color="{{btnType.prefix}}-icon-color" />
            <ColorExample @color="{{btnType.prefix}}-hover-text-color" />
            <ColorExample @color="{{btnType.prefix}}-hover-bg-color" />
            <ColorExample @color="{{btnType.prefix}}-hover-icon-color" />
          </div>
        </div>
      </StyleguideExample>
    {{/each}}
  </template>
}
