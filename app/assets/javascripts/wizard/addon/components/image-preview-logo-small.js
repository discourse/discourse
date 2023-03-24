import { LOREM, drawHeader } from "wizard/lib/preview";
import { observes } from "discourse-common/utils/decorators";
import WizardPreviewBaseComponent from "./wizard-preview-base";

export default WizardPreviewBaseComponent.extend({
  width: 375,
  height: 100,
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return { image: this.get("field.value") };
  },

  paint(options) {
    const { ctx, colors, font, headingFont, width, height } = options;
    const headerHeight = height / 2;

    drawHeader(ctx, colors, width, headerHeight);

    const image = this.image;
    const headerMargin = headerHeight * 0.2;

    const maxWidth = headerHeight - headerMargin * 2.0;
    let imageWidth = image.width;
    let ratio = 1.0;
    if (imageWidth > maxWidth) {
      ratio = maxWidth / imageWidth;
      imageWidth = maxWidth;
    }

    this.scaleImage(
      image,
      headerMargin,
      headerMargin,
      imageWidth,
      image.height * ratio
    );

    const afterLogo = headerMargin * 1.7 + imageWidth;
    const fontSize = Math.round(headerHeight * 0.4);

    ctx.font = `Bold ${fontSize}px '${headingFont}'`;
    ctx.fillStyle = colors.primary;
    const title = LOREM.substring(0, 27);
    ctx.fillText(
      title,
      headerMargin + imageWidth,
      headerHeight - fontSize * 1.1
    );

    const category = this.categories()[0];
    const badgeSize = height / 13.0;
    ctx.beginPath();
    ctx.fillStyle = category.color;
    ctx.rect(afterLogo, headerHeight * 0.7, badgeSize, badgeSize);
    ctx.fill();

    ctx.font = `Bold ${badgeSize * 1.2}px '${font}'`;
    ctx.fillStyle = colors.primary;
    ctx.fillText(
      category.name,
      afterLogo + badgeSize * 1.5,
      headerHeight * 0.7 + badgeSize * 0.9
    );

    const LINE_HEIGHT = 12;
    ctx.font = `${LINE_HEIGHT}px '${font}'`;
    const lines = LOREM.split("\n");
    for (let i = 0; i < 10; i++) {
      const line = height * 0.55 + i * (LINE_HEIGHT * 1.5);
      ctx.fillText(lines[i], afterLogo, line);
    }
  },
});
