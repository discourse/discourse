import { observes } from 'ember-addons/ember-computed-decorators';

import {
  createPreviewComponent,
  loadImage,
  darkLightDiff,
  chooseBrighter,
  drawHeader
} from 'wizard/lib/preview';

const LINE_HEIGHT = 12.0;

const LOREM = `
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Nullam eget sem non elit tincidunt rhoncus. Fusce velit nisl,
porttitor sed nisl ac, consectetur interdum metus. Fusce in
consequat augue, vel facilisis felis. Nunc tellus elit, and
semper vitae orci nec, blandit pharetra enim. Aenean a ebus
posuere nunc. Maecenas ultrices viverra enim ac commodo
Vestibulum nec quam sit amet libero ultricies sollicitudin.
Nulla quis scelerisque sem, eget volutpat velit. Fusce eget
accumsan sapien, nec feugiat quam. Quisque non risus.
placerat lacus vitae, lacinia nisi. Sed metus arcu, iaculis
sit amet cursus nec, sodales at eros.`;

export default createPreviewComponent(400, 220, {
  logo: null,
  avatar: null,

  @observes('step.fieldsById.theme_id.value')
  themeChanged() {
    this.triggerRepaint();
  },

  load() {
    return Ember.RSVP.Promise.all([loadImage('/images/wizard/discourse-small.png'),
                            loadImage('/images/wizard/trout.png')]).then(result => {
      this.logo = result[0];
      this.avatar = result[1];
    });
  },

  paint(ctx, colors, width, height) {
    const headerHeight = height * 0.15;

    drawHeader(ctx, colors, width, headerHeight);

    const margin = width * 0.02;
    const avatarSize = height * 0.1;

    // Logo
    const headerMargin = headerHeight * 0.2;
    const logoHeight = headerHeight - (headerMargin * 2);
    const logoWidth = (logoHeight / this.logo.height) * this.logo.width;
    ctx.drawImage(this.logo, headerMargin, headerMargin, logoWidth, logoHeight);

    // Top right menu
    ctx.drawImage(this.avatar, width - avatarSize - headerMargin, headerMargin, avatarSize, avatarSize);
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 45, 55);
    ctx.font = "0.75em FontAwesome";
    ctx.fillText("\uf0c9", width - (avatarSize * 2) - (headerMargin * 0.5), avatarSize);
    ctx.fillText("\uf002", width - (avatarSize * 3) - (headerMargin * 0.5), avatarSize);

    // Draw a fake topic
    ctx.drawImage(this.avatar, margin, headerHeight + (height * 0.17), avatarSize, avatarSize);

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = "bold 0.75em 'Arial'";
    ctx.fillText("Welcome to Discourse", margin, (height * 0.25));

    ctx.font = "0.5em 'Arial'";

    let line = 0;

    const lines = LOREM.split("\n");
    for (let i=0; i<10; i++) {
      line = (height * 0.3) + (i * LINE_HEIGHT);
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Reply Button
    ctx.beginPath();
    ctx.rect(width * 0.57, line + LINE_HEIGHT, width * 0.1, height * 0.07);
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = chooseBrighter(colors.primary, colors.secondary);
    ctx.font = "8px 'Arial'";
    ctx.fillText("Reply", width * 0.595, line + (LINE_HEIGHT * 1.8));

    // Icons
    ctx.font = "0.5em FontAwesome";
    ctx.fillStyle = colors.love;
    ctx.fillText("\uf004", width * 0.48, line + (LINE_HEIGHT * 1.8));
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 65, 55);
    ctx.fillText("\uf040", width * 0.525, line + (LINE_HEIGHT * 1.8));

    // Draw Timeline
    const timelineX = width * 0.8;
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 0.5;
    ctx.moveTo(timelineX, height * 0.3);
    ctx.lineTo(timelineX, height * 0.6);
    ctx.stroke();

    // Timeline
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 2;
    ctx.moveTo(timelineX, height * 0.3);
    ctx.lineTo(timelineX, height * 0.4);
    ctx.stroke();

    ctx.font = "Bold 0.5em Arial";
    ctx.fillStyle = colors.primary;
    ctx.fillText("1 / 20", timelineX + margin, (height * 0.3) + (margin * 1.5));
  }
});
