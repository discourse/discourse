/*eslint no-bitwise:0 */

import { observes } from 'ember-addons/ember-computed-decorators';

const WIDTH  = 400;
const HEIGHT = 220;
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

function loadImage(src) {
  const img = new Image();
  img.src = src;

  return new Ember.RSVP.Promise(resolve => img.onload = () => resolve(img));
};

function parseColor(color) {
  const m = color.match(/^#([0-9a-f]{6})$/i);
  if (m) {
    const c = m[1];
    return [ parseInt(c.substr(0,2),16), parseInt(c.substr(2,2),16), parseInt(c.substr(4,2),16) ];
  }

  return [0, 0, 0];
}

function brightness(color) {
  return (color[0] * 0.299) + (color[1] * 0.587) + (color[2] * 0.114);
}

function lighten(color, percent) {
  return '#' +
    ((0|(1<<8) + color[0] + (256 - color[0]) * percent / 100).toString(16)).substr(1) +
    ((0|(1<<8) + color[1] + (256 - color[1]) * percent / 100).toString(16)).substr(1) +
    ((0|(1<<8) + color[2] + (256 - color[2]) * percent / 100).toString(16)).substr(1);
}

function chooseBrighter(primary, secondary) {
  const primaryCol = parseColor(primary);
  const secondaryCol = parseColor(secondary);

  return brightness(primaryCol) < brightness(secondaryCol) ? secondary : primary;
}

function darkLightDiff(adjusted, comparison, lightness, darkness) {
  const adjustedCol = parseColor(adjusted);
  const comparisonCol = parseColor(comparison);
  return lighten(adjustedCol, (brightness(adjustedCol) < brightness(comparisonCol)) ?
                               lightness : darkness);
}

export default Ember.Component.extend({
  ctx: null,
  width: WIDTH,
  height: HEIGHT,
  loaded: false,
  logo: null,

  colorScheme: Ember.computed.alias('step.fieldsById.color_scheme.value'),

  didInsertElement() {
    this._super();
    const c = this.$('canvas')[0];
    this.ctx = c.getContext("2d");

    Ember.RSVP.Promise.all([loadImage('/images/wizard/discourse-small.png'),
                            loadImage('/images/wizard/trout.png')]).then(result => {
      this.logo = result[0];
      this.avatar = result[1];
      this.loaded = true;
      this.triggerRepaint();
    });
  },

  @observes('colorScheme')
  triggerRepaint() {
    Ember.run.scheduleOnce('afterRender', this, 'repaint');
  },

  repaint() {
    if (!this.loaded) { return; }

    const { ctx } = this;
    const headerHeight = HEIGHT * 0.15;

    const colorScheme = this.get('colorScheme');
    const options = this.get('step.fieldsById.color_scheme.options');
    const option = options.findProperty('id', colorScheme);
    if (!option) { return; }

    const colors = option.data.colors;
    if (!colors) { return; }

    ctx.fillStyle = colors.secondary;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    // Header area
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, 0, WIDTH, headerHeight);
    ctx.fillStyle = colors.header_background;
    ctx.shadowColor = "rgba(0, 0, 0, 0.25)";
    ctx.shadowBlur = 2;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 2;
    ctx.fill();
    ctx.restore();

    const margin = WIDTH * 0.02;
    const avatarSize = HEIGHT * 0.1;

    // Logo
    const headerMargin = headerHeight * 0.2;
    const logoHeight = headerHeight - (headerMargin * 2);
    const logoWidth = (logoHeight / this.logo.height) * this.logo.width;
    ctx.drawImage(this.logo, headerMargin, headerMargin, logoWidth, logoHeight);

    // Top right menu
    ctx.drawImage(this.avatar, WIDTH - avatarSize - headerMargin, headerMargin, avatarSize, avatarSize);
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 45, 55);
    ctx.font = "0.75em FontAwesome";
    ctx.fillText("\uf0c9", WIDTH - (avatarSize * 2) - (headerMargin * 0.5), avatarSize);
    ctx.fillText("\uf002", WIDTH - (avatarSize * 3) - (headerMargin * 0.5), avatarSize);

    // Draw a fake topic
    ctx.drawImage(this.avatar, margin, headerHeight + (HEIGHT * 0.17), avatarSize, avatarSize);

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = "bold 0.75em 'Arial'";
    ctx.fillText("Welcome to Discourse", margin, (HEIGHT * 0.25));

    ctx.font = "0.5em 'Arial'";

    let line = 0;

    const lines = LOREM.split("\n");
    for (let i=0; i<10; i++) {
      line = (HEIGHT * 0.3) + (i * LINE_HEIGHT);
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Reply Button
    ctx.beginPath();
    ctx.rect(WIDTH * 0.57, line + LINE_HEIGHT, WIDTH * 0.1, HEIGHT * 0.07);
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = chooseBrighter(colors.primary, colors.secondary);
    ctx.font = "8px 'Arial'";
    ctx.fillText("Reply", WIDTH * 0.595, line + (LINE_HEIGHT * 1.8));

    // Icons
    ctx.font = "0.5em FontAwesome";
    ctx.fillStyle = colors.love;
    ctx.fillText("\uf004", WIDTH * 0.48, line + (LINE_HEIGHT * 1.8));
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 65, 55);
    ctx.fillText("\uf040", WIDTH * 0.525, line + (LINE_HEIGHT * 1.8));

    // Draw Timeline
    const timelineX = WIDTH * 0.8;
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 0.5;
    ctx.moveTo(timelineX, HEIGHT * 0.3);
    ctx.lineTo(timelineX, HEIGHT * 0.6);
    ctx.stroke();

    // Timeline
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 2;
    ctx.moveTo(timelineX, HEIGHT * 0.3);
    ctx.lineTo(timelineX, HEIGHT * 0.4);
    ctx.stroke();

    ctx.font = "Bold 0.5em Arial";
    ctx.fillStyle = colors.primary;
    ctx.fillText("1 / 20", timelineX + margin, (HEIGHT * 0.3) + (margin * 1.5));

    // draw border
    ctx.beginPath();
    ctx.strokeStyle='rgba(0, 0, 0, 0.2)';
    ctx.rect(0, 0, WIDTH, HEIGHT);
    ctx.stroke();
  }

});
