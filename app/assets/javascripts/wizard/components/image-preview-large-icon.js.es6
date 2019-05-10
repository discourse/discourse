import { observes } from "ember-addons/ember-computed-decorators";
import { createPreviewComponent } from "wizard/lib/preview";

export default createPreviewComponent(325, 125, {
  ios: null,
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return {
      ios: "/images/wizard/apple-mask.png",
      image: this.get("field.value")
    };
  },

  paint(ctx, colors, width, height) {
    this.scaleImage(this.image, 10, 8, 87, 87);
    this.scaleImage(this.ios, 0, 0, width, height);
  }
});
