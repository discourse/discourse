import { observes } from 'ember-addons/ember-computed-decorators';

import {
  createPreviewComponent,
  loadImage,
} from 'wizard/lib/preview';

export default createPreviewComponent(371, 124, {
  tab: null,
  image: null,

  @observes('field.value')
  imageChanged() {
    this.reload();
  },

  load() {
    return Ember.RSVP.Promise.all([
        loadImage('/images/wizard/tab.png'),
        loadImage(this.get('field.value'))
    ]).then(result => {
      this.tab = result[0];
      this.image = result[1];
    });

    return loadImage(this.get('field.value')).then(image => {
      this.image = image;
    });
  },

  paint(ctx, colors, width, height) {
    ctx.drawImage(this.tab, 0, 0, width, height);
    ctx.drawImage(this.image, 40, 25, 30, 30);

    ctx.font = `20px 'Arial'`;
    ctx.fillStyle = '#000';

    let title = this.get('wizard').getTitle();
    if (title.length > 20) {
      title = title.substring(0, 20) + "...";
    }

    ctx.fillText(title, 80, 48);
  }
});
