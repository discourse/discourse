import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezones-reset", {
  tagName: "div.group-timezones-reset",

  onResetOffset() {
    this.sendWidgetAction("onChangeCurrentUserTimeOffset", 0);

    const container = document.getElementById(this.attrs.id);
    const slider = container.querySelector(
      "input[type=range].group-timezones-slider"
    );
    if (slider) {
      slider.value = 0;
    }
  },

  transform(attrs) {
    return {
      isDisabled: attrs.localTimeOffset === 0,
    };
  },

  template: hbs`
    {{attach
      widget="button"
      attrs=(hash
        disabled=this.transformed.isDisabled
        action="onResetOffset"
        icon="arrow-rotate-left"
      )
    }}
  `,
});
