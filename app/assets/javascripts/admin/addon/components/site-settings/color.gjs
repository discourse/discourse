import Component from "@glimmer/component";
import ColorInput from "admin/components/color-input";

const SETTINGS_WITH_FALLBACK_COLORS = ["welcome_banner_text_color"];

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
  get fallbackColor() {
    if (SETTINGS_WITH_FALLBACK_COLORS.includes(this.args.setting?.setting)) {
      return getComputedStyle(document.documentElement).getPropertyValue(
        "--primary"
      );
    }
    return null;
  }

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

  <template>
    <ColorInput
      @hexValue={{readonly @value}}
      @fallbackHexValue={{this.fallbackColor}}
      @valid={{@valid}}
      @onlyHex={{false}}
      @styleSelection={{false}}
      @onChangeColor={{@changeValueCallback}}
    />
  </template>
}
