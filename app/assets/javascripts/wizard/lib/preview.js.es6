import { scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
/*eslint no-bitwise:0 */
import getUrl from "discourse-common/lib/get-url";
import { Promise } from "rsvp";

export const LOREM = `
Lorem ipsum dolor sit amet,
consectetur adipiscing elit.
Nullam eget sem non elit
tincidunt rhoncus. Fusce
velit nisl, porttitor sed
nisl ac, consectetur interdum
metus. Fusce in consequat
augue, vel facilisis felis.`;

const scaled = {};

function canvasFor(image, w, h) {
  w = Math.ceil(w);
  h = Math.ceil(h);

  const scale = window.devicePixelRatio;

  const can = document.createElement("canvas");
  can.width = w * scale;
  can.height = h * scale;

  const ctx = can.getContext("2d");
  ctx.scale(scale, scale);
  ctx.drawImage(image, 0, 0, w, h);
  return can;
}

export function createPreviewComponent(width, height, obj) {
  const scale = window.devicePixelRatio;
  return Component.extend(
    {
      layoutName: "components/theme-preview",
      width,
      height,
      elementWidth: width * scale,
      elementHeight: height * scale,
      ctx: null,
      loaded: false,

      didInsertElement() {
        this._super(...arguments);
        const c = this.element.querySelector("canvas");
        this.ctx = c.getContext("2d");
        this.ctx.scale(scale, scale);
        this.reload();
      },

      images() {},

      loadImages() {
        const images = this.images();
        if (images) {
          return Promise.all(
            Object.keys(images).map(id => {
              return loadImage(images[id]).then(img => (this[id] = img));
            })
          );
        }
        return Promise.resolve();
      },

      reload() {
        this.loadImages().then(() => {
          this.loaded = true;
          this.triggerRepaint();
        });
      },

      triggerRepaint() {
        scheduleOnce("afterRender", this, "repaint");
      },

      repaint() {
        if (!this.loaded) {
          return false;
        }

        const colors = this.wizard.getCurrentColors(this.colorsId);
        if (!colors) {
          return;
        }

        const { ctx } = this;

        ctx.fillStyle = colors.secondary;
        ctx.fillRect(0, 0, width, height);

        this.paint(ctx, colors, this.width, this.height);

        // draw border
        ctx.beginPath();
        ctx.strokeStyle = "rgba(0, 0, 0, 0.2)";
        ctx.rect(0, 0, width, height);
        ctx.stroke();
      },

      categories() {
        return [
          { name: "consecteteur", color: "#652D90" },
          { name: "ultrices", color: "#3AB54A" },
          { name: "placerat", color: "#25AAE2" }
        ];
      },

      scaleImage(image, x, y, w, h) {
        w = Math.floor(w);
        h = Math.floor(h);

        const { ctx } = this;

        const key = `${image.src}-${w}-${h}`;

        if (!scaled[key]) {
          let copy = image;
          let ratio = copy.width / copy.height;
          let newH = copy.height * 0.5;
          while (newH > h) {
            copy = canvasFor(copy, ratio * newH, newH);
            newH = newH * 0.5;
          }

          scaled[key] = copy;
        }

        ctx.drawImage(scaled[key], x, y, w, h);
      },

      drawFullHeader(colors) {
        const { ctx } = this;

        const headerHeight = height * 0.15;
        drawHeader(ctx, colors, width, headerHeight);

        const avatarSize = height * 0.1;

        // Logo
        const headerMargin = headerHeight * 0.2;
        const logoHeight = headerHeight - headerMargin * 2;

        ctx.beginPath();
        ctx.fillStyle = colors.header_primary;
        ctx.font = `bold ${logoHeight}px 'Arial'`;
        ctx.fillText("Discourse", headerMargin, headerHeight - headerMargin);

        // Top right menu
        this.scaleImage(
          this.avatar,
          width - avatarSize - headerMargin,
          headerMargin,
          avatarSize,
          avatarSize
        );
        ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 45, 55);

        const pathScale = headerHeight / 1200;
        // search icon SVG path
        const searchIcon = new Path2D(
          "M505 442.7L405.3 343c-4.5-4.5-10.6-7-17-7H372c27.6-35.3 44-79.7 44-128C416 93.1 322.9 0 208 0S0 93.1 0 208s93.1 208 208 208c48.3 0 92.7-16.4 128-44v16.3c0 6.4 2.5 12.5 7 17l99.7 99.7c9.4 9.4 24.6 9.4 33.9 0l28.3-28.3c9.4-9.4 9.4-24.6.1-34zM208 336c-70.7 0-128-57.2-128-128 0-70.7 57.2-128 128-128 70.7 0 128 57.2 128 128 0 70.7-57.2 128-128 128z"
        );
        // hamburger icon
        const hamburgerIcon = new Path2D(
          "M16 132h416c8.837 0 16-7.163 16-16V76c0-8.837-7.163-16-16-16H16C7.163 60 0 67.163 0 76v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16z"
        );
        ctx.save(); // Save the previous state for translation and scale
        ctx.translate(
          width - avatarSize * 3 - headerMargin * 0.5,
          avatarSize / 2
        );
        // need to scale paths otherwise they're too large
        ctx.scale(pathScale, pathScale);
        ctx.fill(searchIcon);
        ctx.restore();
        ctx.save();
        ctx.translate(
          width - avatarSize * 2 - headerMargin * 0.5,
          avatarSize / 2
        );
        ctx.scale(pathScale, pathScale);
        ctx.fill(hamburgerIcon);
        ctx.restore();
      },

      drawPills(colors, headerHeight, opts) {
        opts = opts || {};

        const { ctx } = this;

        const categoriesSize = headerHeight * 2;
        const badgeHeight = categoriesSize * 0.25;
        const headerMargin = headerHeight * 0.2;

        ctx.beginPath();
        ctx.strokeStyle = colors.primary;
        ctx.lineWidth = 0.5;
        ctx.rect(
          headerMargin,
          headerHeight + headerMargin,
          categoriesSize,
          badgeHeight
        );
        ctx.stroke();

        const fontSize = Math.round(badgeHeight * 0.5);

        ctx.font = `${fontSize}px 'Arial'`;
        ctx.fillStyle = colors.primary;
        ctx.fillText(
          "all categories",
          headerMargin * 1.5,
          headerHeight + headerMargin * 1.4 + fontSize
        );

        const pathScale = badgeHeight / 1000;
        // caret icon
        const caretIcon = new Path2D(
          "M0 384.662V127.338c0-17.818 21.543-26.741 34.142-14.142l128.662 128.662c7.81 7.81 7.81 20.474 0 28.284L34.142 398.804C21.543 411.404 0 402.48 0 384.662z"
        );

        ctx.save();
        ctx.translate(
          categoriesSize - headerMargin / 4,
          headerHeight + headerMargin + badgeHeight / 4
        );
        ctx.scale(pathScale, pathScale);
        ctx.fill(caretIcon);
        ctx.restore();

        const text = opts.categories ? "Categories" : "Latest";

        const activeWidth = categoriesSize * (opts.categories ? 0.8 : 0.55);
        ctx.beginPath();
        ctx.fillStyle = colors.quaternary;
        ctx.rect(
          headerMargin * 2 + categoriesSize,
          headerHeight + headerMargin,
          activeWidth,
          badgeHeight
        );
        ctx.fill();

        ctx.font = `${fontSize}px 'Arial'`;
        ctx.fillStyle = colors.secondary;
        let x = headerMargin * 3.0 + categoriesSize;
        ctx.fillText(
          text,
          x - headerMargin * 0.1,
          headerHeight + headerMargin * 1.5 + fontSize
        );

        ctx.fillStyle = colors.primary;
        x += categoriesSize * (opts.categories ? 0.8 : 0.6);
        ctx.fillText("New", x, headerHeight + headerMargin * 1.5 + fontSize);

        x += categoriesSize * 0.4;
        ctx.fillText("Unread", x, headerHeight + headerMargin * 1.5 + fontSize);

        x += categoriesSize * 0.6;
        ctx.fillText("Top", x, headerHeight + headerMargin * 1.5 + fontSize);
      }
    },
    obj
  );
}

function loadImage(src) {
  if (!src) {
    return Promise.resolve();
  }

  const img = new Image();
  img.src = getUrl(src);
  return new Promise(resolve => (img.onload = () => resolve(img)));
}

export function parseColor(color) {
  const m = color.match(/^#([0-9a-f]{6})$/i);
  if (m) {
    const c = m[1];
    return [
      parseInt(c.substr(0, 2), 16),
      parseInt(c.substr(2, 2), 16),
      parseInt(c.substr(4, 2), 16)
    ];
  }

  return [0, 0, 0];
}

export function brightness(color) {
  return color[0] * 0.299 + color[1] * 0.587 + color[2] * 0.114;
}

function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  let max = Math.max(r, g, b),
    min = Math.min(r, g, b);
  let h,
    s,
    l = (max + min) / 2;

  if (max === min) {
    h = s = 0;
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r:
        h = (g - b) / d + (g < b ? 6 : 0);
        break;
      case g:
        h = (b - r) / d + 2;
        break;
      case b:
        h = (r - g) / d + 4;
        break;
    }
    h /= 6;
  }

  return [h, s, l];
}

function hue2rgb(p, q, t) {
  if (t < 0) {
    t += 1;
  }
  if (t > 1) {
    t -= 1;
  }
  if (t < 1 / 6) {
    return p + (q - p) * 6 * t;
  }
  if (t < 1 / 2) {
    return q;
  }
  if (t < 2 / 3) {
    return p + (q - p) * (2 / 3 - t) * 6;
  }
  return p;
}

function hslToRgb(h, s, l) {
  let r, g, b;

  if (s === 0) {
    r = g = b = l; // achromatic
  } else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return [r * 255, g * 255, b * 255];
}

export function lighten(color, percent) {
  const hsl = rgbToHsl(color[0], color[1], color[2]);
  const scale = percent / 100.0;
  const diff = scale > 0 ? 1.0 - hsl[2] : hsl[2];

  hsl[2] = hsl[2] + diff * scale;
  color = hslToRgb(hsl[0], hsl[1], hsl[2]);

  return (
    "#" +
    (0 | ((1 << 8) + color[0])).toString(16).substr(1) +
    (0 | ((1 << 8) + color[1])).toString(16).substr(1) +
    (0 | ((1 << 8) + color[2])).toString(16).substr(1)
  );
}

export function chooseBrighter(primary, secondary) {
  const primaryCol = parseColor(primary);
  const secondaryCol = parseColor(secondary);
  return brightness(primaryCol) < brightness(secondaryCol)
    ? secondary
    : primary;
}

export function chooseDarker(primary, secondary) {
  if (chooseBrighter(primary, secondary) === primary) {
    return secondary;
  } else {
    return primary;
  }
}

export function darkLightDiff(adjusted, comparison, lightness, darkness) {
  const adjustedCol = parseColor(adjusted);
  const comparisonCol = parseColor(comparison);
  return lighten(
    adjustedCol,
    brightness(adjustedCol) < brightness(comparisonCol) ? lightness : darkness
  );
}

export function drawHeader(ctx, colors, width, headerHeight) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, width, headerHeight);
  ctx.fillStyle = colors.header_background;
  ctx.shadowColor = "rgba(0, 0, 0, 0.25)";
  ctx.shadowBlur = 2;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 2;
  ctx.fill();
  ctx.restore();
}
