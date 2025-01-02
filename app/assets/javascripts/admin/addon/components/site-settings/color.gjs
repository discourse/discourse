import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import ColorInput from "admin/components/color-input";

function RGBToHex(rgb) {
  // Choose correct separator
  let sep = rgb.includes(",") ? "," : " ";
  // Turn "rgb(r,g,b)" into [r,g,b]
  rgb = rgb.slice(4).split(")")[0].split(sep);

  let r = (+rgb[0]).toString(16),
    g = (+rgb[1]).toString(16),
    b = (+rgb[2]).toString(16);

  if (r.length === 1) {
    r = "0" + r;
  }
  if (g.length === 1) {
    g = "0" + g;
  }
  if (b.length === 1) {
    b = "0" + b;
  }

  return "#" + r + g + b;
}

export default class Color extends Component {
  @computed("value")
  get valid() {
    let value = this.args.value.toLowerCase();

    let testColor = new Option().style;
    testColor.color = value;

    if (!testColor.color && !value.startsWith("#")) {
      value = `#${value}`;
      testColor = new Option().style;
      testColor.color = value;
    }

    let hexifiedColor = RGBToHex(testColor.color);
    if (hexifiedColor.includes("NaN")) {
      hexifiedColor = testColor.color;
    }

    return testColor.color && hexifiedColor === value;
  }

  @action
  onChangeColor(color) {
    this.args.changeValueCallback(color);
  }

  <template>
    <ColorInput
      @hexValue={{readonly @value}}
      @valid={{@valid}}
      @onlyHex={{false}}
      @styleSelection={{false}}
      @onChangeColor={{this.onChangeColor}}
    />
  </template>
}
