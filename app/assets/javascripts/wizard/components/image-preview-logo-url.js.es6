import { observes } from "ember-addons/ember-computed-decorators";

import { createPreviewComponent, drawHeader } from "wizard/lib/preview";

export default createPreviewComponent(400, 100, {
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return { image: this.get("field.value") };
  },

  paint(ctx, colors, width, height) {
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

    this.drawPills(colors, height / 2);
  }
});
