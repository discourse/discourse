import { drawHeader } from "wizard/lib/preview";
import { observes } from "discourse-common/utils/decorators";
import WizardPreviewBaseComponent from "./wizard-preview-base";

export default WizardPreviewBaseComponent.extend({
  width: 400,
  height: 100,
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return { image: this.get("field.value") };
  },

  paint({ ctx, colors, font, width, height }) {
    const headerHeight = height / 2;

    drawHeader(ctx, colors, width, headerHeight);

    const image = this.image;

    const headerMargin = headerHeight * 0.2;

    const imageHeight = headerHeight - headerMargin * 2;
    const ratio = imageHeight / image.height;
    this.scaleImage(
      image,
      headerMargin,
      headerMargin,
      image.width * ratio,
      imageHeight
    );

    this.drawPills(colors, font, height / 2);
  },
});
