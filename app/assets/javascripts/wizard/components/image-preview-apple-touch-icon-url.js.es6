import { observes } from 'ember-addons/ember-computed-decorators';

import {
  createPreviewComponent,
  loadImage,
} from 'wizard/lib/preview';

export default createPreviewComponent(325, 125, {
  ios: null,
  image: null,

  @observes('field.value')
  imageChanged() {
    this.reload();
  },

  load() {
    return Ember.RSVP.Promise.all([
      loadImage('/images/wizard/apple-mask.png'),
      loadImage(this.get('field.value'))
    ]).then(result => {
      this.ios = result[0];
      this.image = result[1];
    });

    return loadImage(this.get('field.value')).then(image => {
      this.image = image;
    });
  },

  paint(ctx, colors, width, height) {
    ctx.drawImage(this.image, 10, 8, 87, 87);
    ctx.drawImage(this.ios, 0, 0, width, height);
  }
});
