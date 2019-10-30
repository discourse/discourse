import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import { default as loadScript, loadCSS } from "discourse/lib/load-script";

/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.
  @param brightnessValue is a number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @params valid is a boolean indicating if the input field is a valid color.
**/
export default Component.extend({
  classNames: ["color-picker"],
  hexValueChanged: function() {
    var hex = this.hexValue;
    let text = this.element.querySelector("input.hex-input");

    if (this.valid) {
      text.setAttribute(
        "style",
        "color: " +
          (this.brightnessValue > 125 ? "black" : "white") +
          "; background-color: #" +
          hex +
          ";"
      );

      if (this.pickerLoaded) {
        $(this.element.querySelector(".picker")).spectrum({
          color: "#" + this.hexValue
        });
      }
    } else {
      text.setAttribute("style", "");
    }
  }.observes("hexValue", "brightnessValue", "valid"),

  didInsertElement() {
    loadScript("/javascripts/spectrum.js").then(() => {
      loadCSS("/javascripts/spectrum.css").then(() => {
        schedule("afterRender", () => {
          $(this.element.querySelector(".picker"))
            .spectrum({ color: "#" + this.hexValue })
            .on("change.spectrum", (me, color) => {
              this.set("hexValue", color.toHexString().replace("#", ""));
            });
          this.set("pickerLoaded", true);
        });
      });
    });
    schedule("afterRender", () => {
      this.hexValueChanged();
    });
  }
});
