import { default as loadScript, loadCSS } from "discourse/lib/load-script";

/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.
  @param brightnessValue is a number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @params valid is a boolean indicating if the input field is a valid color.
**/
export default Ember.Component.extend({
  classNames: ["color-picker"],
  hexValueChanged: function() {
    var hex = this.hexValue;
    let $text = this.$("input.hex-input");

    if (this.valid) {
      $text.attr(
        "style",
        "color: " +
          (this.brightnessValue > 125 ? "black" : "white") +
          "; background-color: #" +
          hex +
          ";"
      );

      if (this.pickerLoaded) {
        this.$(".picker").spectrum({ color: "#" + this.hexValue });
      }
    } else {
      $text.attr("style", "");
    }
  }.observes("hexValue", "brightnessValue", "valid"),

  didInsertElement() {
    loadScript("/javascripts/spectrum.js").then(() => {
      loadCSS("/javascripts/spectrum.css").then(() => {
        Ember.run.schedule("afterRender", () => {
          this.$(".picker")
            .spectrum({ color: "#" + this.hexValue })
            .on("change.spectrum", (me, color) => {
              this.set("hexValue", color.toHexString().replace("#", ""));
            });
          this.set("pickerLoaded", true);
        });
      });
    });
    Ember.run.schedule("afterRender", () => {
      this.hexValueChanged();
    });
  }
});
