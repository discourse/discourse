import { observes } from 'ember-addons/ember-computed-decorators';

import {
  createPreviewComponent,
  loadImage,
  drawHeader,
  darkLightDiff
} from 'wizard/lib/preview';

export default createPreviewComponent(400, 100, {
  image: null,

  @observes('field.value')
  imageChanged() {
    this.reload();
  },

  load() {
    return loadImage(this.get('field.value')).then(image => {
      this.image = image;
    });
  },

  paint(ctx, colors, width, height) {
    const headerHeight = height / 2;

    drawHeader(ctx, colors, width, headerHeight);

    const image = this.image;
    const headerMargin = headerHeight * 0.2;

    const imageHeight = headerHeight - (headerMargin * 2);
    const ratio = imageHeight / image.height;
    ctx.drawImage(image, headerMargin, headerMargin, image.width * ratio, imageHeight);

    const categoriesSize = width / 3.8;
    const badgeHeight = categoriesSize * 0.25;

    ctx.beginPath();
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 90, -65);
    ctx.rect(headerMargin, headerHeight + headerMargin, categoriesSize, badgeHeight);
    ctx.fill();

    const fontSize = Math.round(badgeHeight * 0.5);
    ctx.font = `${fontSize}px 'Arial'`;
    ctx.fillStyle = colors.primary;
    ctx.fillText("all categories", headerMargin * 1.5, headerHeight + (headerMargin * 1.5) + fontSize);

    ctx.font = "0.9em 'FontAwesome'";
    ctx.fillStyle = colors.primary;
    ctx.fillText("\uf0da", categoriesSize - (headerMargin / 4), headerHeight + (headerMargin * 1.6) + fontSize);

    // pills
    ctx.beginPath();
    ctx.fillStyle = colors.quaternary;
    ctx.rect((headerMargin * 2)+ categoriesSize, headerHeight + headerMargin, categoriesSize * 0.55, badgeHeight);
    ctx.fill();

    ctx.font = `${fontSize}px 'Arial'`;
    ctx.fillStyle = colors.secondary;
    let x = (headerMargin * 3.0) + categoriesSize;

    ctx.fillText("Latest", x, headerHeight + (headerMargin * 1.5) + fontSize);

    ctx.fillStyle = colors.primary;
    x += categoriesSize * 0.6;
    ctx.fillText("New", x, headerHeight + (headerMargin * 1.5) + fontSize);

    x += categoriesSize * 0.4;
    ctx.fillText("Unread", x, headerHeight + (headerMargin * 1.5) + fontSize);

    x += categoriesSize * 0.6;
    ctx.fillText("Top", x, headerHeight + (headerMargin * 1.5) + fontSize);
  }

});
