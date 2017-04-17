import { observes } from 'ember-addons/ember-computed-decorators';

import {
  createPreviewComponent,
  darkLightDiff,
  chooseBrighter,
  LOREM
} from 'wizard/lib/preview';

export default createPreviewComponent(659, 320, {
  logo: null,
  avatar: null,

  @observes('step.fieldsById.base_scheme_id.value')
  themeChanged() {
    this.triggerRepaint();
  },

  images() {
    return { logo: this.get('wizard').getLogoUrl(), avatar: '/images/wizard/trout.png' };
  },

  paint(ctx, colors, width, height) {
    const headerHeight = height * 0.15;

    this.drawFullHeader(colors);

    const margin = width * 0.02;
    const avatarSize = height * 0.1;
    const lineHeight = height / 19.0;

    // Draw a fake topic
    this.scaleImage(this.avatar, margin, headerHeight + (height * 0.17), avatarSize, avatarSize);

    const titleFontSize = headerHeight / 44;

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = `bold ${titleFontSize}em 'Arial'`;
    ctx.fillText("Welcome to Discourse", margin, (height * 0.25));

    const bodyFontSize = height / 440.0;
    ctx.font = `${bodyFontSize}em 'Arial'`;

    let line = 0;
    const lines = LOREM.split("\n");
    for (let i=0; i<10; i++) {
      line = (height * 0.3) + (i * lineHeight);
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Reply Button
    ctx.beginPath();
    ctx.rect(width * 0.57, line + lineHeight, width * 0.1, height * 0.07);
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = chooseBrighter(colors.primary, colors.secondary);
    ctx.font = `${bodyFontSize}em 'Arial'`;
    ctx.fillText("Reply", width * 0.595, line + (lineHeight * 1.85));

    // Icons
    ctx.font = `${bodyFontSize}em FontAwesome`;
    ctx.fillStyle = colors.love;
    ctx.fillText("\uf004", width * 0.48, line + (lineHeight * 1.8));
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 65, 55);
    ctx.fillText("\uf040", width * 0.525, line + (lineHeight * 1.8));

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

    ctx.font = `Bold ${bodyFontSize}em Arial`;
    ctx.fillStyle = colors.primary;
    ctx.fillText("1 / 20", timelineX + margin, (height * 0.3) + (margin * 1.5));
  }
});
