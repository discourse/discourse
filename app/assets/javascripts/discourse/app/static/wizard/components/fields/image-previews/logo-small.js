import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import { drawHeader } from "../../../lib/preview";
import PreviewBaseComponent from "../styling-preview/-preview-base";

export default class LogoSmall extends PreviewBaseComponent {
  width = 375;
  height = 100;
  image = null;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.field.addListener(this.imageChanged);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.field.removeListener(this.imageChanged);
  }

  @action
  imageChanged() {
    this.reload();
  }

  images() {
    return { image: this.field.value };
  }

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
    const fontSize = Math.round(headerHeight * 0.3);

    ctx.font = `Bold ${fontSize}px '${headingFont}'`;
    ctx.fillStyle = colors.primary;
    const title = i18n("wizard.homepage_preview.topic_titles.what_books");
    ctx.fillText(
      title,
      headerMargin + imageWidth + 10,
      headerHeight - fontSize * 1.8
    );

    const category = this.categories()[0];
    const badgeSize = height / 13.0;
    ctx.beginPath();
    ctx.fillStyle = category.color;
    ctx.rect(afterLogo + 2, headerHeight * 0.6, badgeSize, badgeSize);
    ctx.fill();

    ctx.font = `Bold ${badgeSize * 1.2}px '${font}'`;
    ctx.fillStyle = colors.primary;
    ctx.fillText(
      category.name,
      afterLogo + badgeSize * 1.5,
      headerHeight * 0.6 + badgeSize * 0.9
    );

    const LINE_HEIGHT = 12;
    ctx.font = `${LINE_HEIGHT}px '${font}'`;
    const opFirstSentenceLines = i18n(
      "wizard.homepage_preview.topic_ops.what_books"
    )
      .split(".")[0]
      .split("\n");
    for (let i = 0; i < 2; i++) {
      const line = height * 0.7 + i * (LINE_HEIGHT * 1.5);
      ctx.fillText(opFirstSentenceLines[i], afterLogo, line);
    }
  }
}
