/*eslint no-bitwise:0 */
import Component from "@ember/component";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { Promise } from "rsvp";
import PreloadStore from "discourse/lib/preload-store";
import getUrl from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";
import { darkLightDiff, drawHeader } from "../../../lib/preview";

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

const scale = window.devicePixelRatio;
export default class PreviewBase extends Component {
  ctx = null;
  loaded = false;
  loadingFontVariants = false;

  get elementWidth() {
    return this.width * scale;
  }

  get elementHeight() {
    return this.height * scale;
  }

  get canvasStyle() {
    return htmlSafe(`width:${this.width}px;height:${this.height}px`);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.fontMap = PreloadStore.get("fontMap");
    this.loadedFonts = new Set();
    const c = this.element.querySelector("canvas");
    this.ctx = c.getContext("2d");
    this.ctx.scale(scale, scale);

    if (this.step) {
      this.step.findField("color_scheme")?.addListener(this.themeChanged);
      this.step.findField("homepage_style")?.addListener(this.themeChanged);
      this.step.findField("body_font")?.addListener(this.themeBodyFontChanged);
      this.step
        .findField("heading_font")
        ?.addListener(this.themeHeadingFontChanged);
    }

    this.reload();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    if (this.step) {
      this.step.findField("color_scheme")?.removeListener(this.themeChanged);
      this.step.findField("homepage_style")?.removeListener(this.themeChanged);
      this.step
        .findField("body_font")
        ?.removeListener(this.themeBodyFontChanged);
      this.step
        .findField("heading_font")
        ?.removeListener(this.themeHeadingFontChanged);
    }
  }

  @action
  themeChanged() {
    this.triggerRepaint();
  }

  @action
  themeBodyFontChanged() {
    if (!this.loadingFontVariants) {
      this.loadFontVariants(this.wizard.font);
    }
  }

  @action
  themeHeadingFontChanged() {
    if (!this.loadingFontVariants) {
      this.loadFontVariants(this.wizard.headingFont);
    }
  }

  loadFontVariants(font) {
    const fontVariantData = this.fontMap[font.id];

    // System font for example does not need to load from a remote source.
    if (!fontVariantData) {
      this.loadedFonts.add(font.id);
    }

    if (fontVariantData && !this.loadedFonts.has(font.id)) {
      this.loadingFontVariants = true;
      const fontFaces = fontVariantData.map((fontVariant) => {
        return new FontFace(font.label, `url(${fontVariant.url})`, {
          style: "normal",
          weight: fontVariant.weight,
        });
      });

      Promise.all(
        fontFaces.map((fontFace) =>
          fontFace.load().then((loadedFont) => {
            document.fonts.add(loadedFont);

            // We use our own Set because, though document.fonts.check is available,
            // it does not seem very reliable, returning false for fonts that have
            // definitely been loaded.
            this.loadedFonts.add(font.id);
          })
        )
      )
        .then(() => {
          this.triggerRepaint();
        })
        .finally(() => {
          this.loadingFontVariants = false;
        });
    } else if (this.loadedFonts.has(font.id)) {
      this.triggerRepaint();
    }
  }

  images() {}

  // NOTE: This works for fonts included in a style that is actually using the
  // @font-faces on load, but for fonts that we aren't using yet we need to
  // make sure they are loaded before rendering the canvas via loadFontVariants.
  loadFonts() {
    return document.fonts.ready;
  }

  loadImages() {
    const images = this.images();
    if (images) {
      return Promise.all(
        Object.keys(images).map((id) => {
          return loadImage(images[id]).then((img) => (this[id] = img));
        })
      );
    }
    return Promise.resolve();
  }

  reload() {
    Promise.all([this.loadFonts(), this.loadImages()]).then(() => {
      this.loaded = true;
      this.triggerRepaint();
    });
  }

  triggerRepaint() {
    scheduleOnce("afterRender", this, "repaint");
  }

  repaint() {
    if (!this.loaded) {
      return false;
    }

    const colorsArray = this.wizard.currentColors;
    if (!colorsArray) {
      return;
    }

    let colors = {};
    colorsArray.forEach(function (c) {
      const name = c.name;
      colors[name] = `#${c.hex}`;
    });

    const { font, headingFont } = this.wizard;
    if (!font) {
      return;
    }

    const { ctx } = this;

    ctx.fillStyle = colors.secondary;
    ctx.fillRect(0, 0, this.width, this.height);

    const options = {
      ctx,
      colors,
      font: font?.label,
      headingFont: headingFont?.label,
      width: this.width,
      height: this.height,
    };
    this.paint(options);
  }

  categories() {
    return [
      {
        name: i18n("wizard.homepage_preview.category_names.icebreakers"),
        color: "#652D90",
      },
      {
        name: i18n("wizard.homepage_preview.category_names.news"),
        color: "#3AB54A",
      },
      {
        name: i18n("wizard.homepage_preview.category_names.site_feedback"),
        color: "#25AAE2",
      },
    ];
  }

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
  }

  drawFullHeader(colors, font, logo) {
    const { ctx } = this;

    const headerHeight = this.height * 0.15;
    drawHeader(ctx, colors, this.width, headerHeight);

    const avatarSize = this.height * 0.1;
    const headerMargin = headerHeight * 0.2;

    if (logo) {
      const logoHeight = headerHeight - headerMargin * 2;

      const ratio = logoHeight / logo.height;
      this.scaleImage(
        logo,
        headerMargin,
        headerMargin,
        logo.width * ratio,
        logoHeight
      );

      this.scaleImage(logo, this.width, headerMargin);
    }

    // Top right menu
    this.scaleImage(
      this.avatar,
      this.width - avatarSize - headerMargin,
      headerMargin,
      avatarSize,
      avatarSize
    );
    // accounts for hard-set color variables in solarized themes
    ctx.fillStyle =
      colors.primary_low_mid ||
      darkLightDiff(colors.primary, colors.secondary, 45, 55);

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
      this.width - avatarSize * 3 - headerMargin * 0.5,
      avatarSize / 2
    );
    // need to scale paths otherwise they're too large
    ctx.scale(pathScale, pathScale);
    ctx.fill(searchIcon);
    ctx.restore();
    ctx.save();
    ctx.translate(
      this.width - avatarSize * 2 - headerMargin * 0.5,
      avatarSize / 2
    );
    ctx.scale(pathScale, pathScale);
    ctx.fill(hamburgerIcon);
    ctx.restore();
  }

  drawPills(colors, font, headerHeight, opts) {
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

    ctx.font = `${fontSize}px '${font}'`;
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
    ctx.fillStyle = colors.tertiary;
    ctx.rect(
      headerMargin * 2 + categoriesSize,
      headerHeight + headerMargin,
      activeWidth,
      badgeHeight
    );
    ctx.fill();

    ctx.font = `${fontSize}px '${font}'`;
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
}

function loadImage(src) {
  if (!src) {
    return Promise.resolve();
  }

  const img = new Image();
  img.src = getUrl(src);
  return new Promise((resolve) => (img.onload = () => resolve(img)));
}
