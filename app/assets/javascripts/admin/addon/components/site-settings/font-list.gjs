import Component from "@glimmer/component";
import FontSelector from "select-kit/components/font-selector";

export default class FontList extends Component {
  get choices() {
    const classPrefix =
      this.args.setting.setting === "heading_font"
        ? "heading-font-"
        : "body-font-";

    return this.args.setting.choices.map((choice) => {
      return {
        classNames: classPrefix + choice.value.replace(/_/g, "-"),
        id: choice.value,
        name: choice.name,
      };
    });
  }

  <template>
    <FontSelector
      @value={{@value}}
      @content={{this.choices}}
      @onChange={{@changeValueCallback}}
    />
  </template>
}
