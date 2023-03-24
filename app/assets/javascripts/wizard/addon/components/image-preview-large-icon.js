import { observes } from "discourse-common/utils/decorators";
import WizardPreviewBaseComponent from "./wizard-preview-base";

export default WizardPreviewBaseComponent.extend({
  width: 325,
  height: 125,
  ios: null,
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return {
      ios: "/images/wizard/apple-mask.png",
      image: this.get("field.value"),
    };
  },

  paint(options) {
    const { width, height } = options;
    this.scaleImage(this.image, 10, 8, 87, 87);
    this.scaleImage(this.ios, 0, 0, width, height);
  },
});
