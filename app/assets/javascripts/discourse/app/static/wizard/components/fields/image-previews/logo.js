import { action } from "@ember/object";
import { drawHeader } from "../../../lib/preview";
import PreviewBaseComponent from "../styling-preview/-preview-base";

export default class Logo extends PreviewBaseComponent {
  width = 400;
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

    this.drawPills(colors, font, height / 2, { homepageStyle: "hot" });
  }
}
