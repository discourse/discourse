import { observes } from "ember-addons/ember-computed-decorators";

import { createPreviewComponent } from "wizard/lib/preview";

export default createPreviewComponent(371, 124, {
  tab: null,
  image: null,

  @observes("field.value")
  imageChanged() {
    this.reload();
  },

  images() {
    return { tab: "/images/wizard/tab.png", image: this.get("field.value") };
  },

  paint(ctx, colors, width, height) {
    this.scaleImage(this.tab, 0, 0, width, height);
    this.scaleImage(this.image, 40, 25, 30, 30);

    ctx.font = `20px 'Arial'`;
    ctx.fillStyle = "#000";

    let title = this.get("wizard").getTitle();
    if (title.length > 20) {
      title = title.substring(0, 20) + "...";
    }

    ctx.fillText(title, 80, 48);
  }
});
