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

      return Promise.all(
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
      return Promise.resolve(this.triggerRepaint());
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
      // NOTE: This must be done otherwise the "bold" variant of the body font
      // will not be loaded for some reason before rendering the canvas.
      //
      // The header font does not suffer from this issue.
      this.loadFontVariants(this.wizard.font).then(() => {
        this.loaded = true;
        this.triggerRepaint();
      });
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

  get headerHeight() {
    return this.height * 0.15;
  }

  drawFullHeader(colors, font, logo) {
    const { ctx } = this;

    drawHeader(ctx, colors, this.width, this.headerHeight);

    const avatarSize = this.height * 0.1;
    const headerMargin = this.headerHeight * 0.2;

    if (logo) {
      const logoHeight = this.headerHeight - headerMargin * 2;

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

    const pathScale = this.headerHeight / 1200;
    const searchIcon = new Path2D(
      "M505 442.7L405.3 343c-4.5-4.5-10.6-7-17-7H372c27.6-35.3 44-79.7 44-128C416 93.1 322.9 0 208 0S0 93.1 0 208s93.1 208 208 208c48.3 0 92.7-16.4 128-44v16.3c0 6.4 2.5 12.5 7 17l99.7 99.7c9.4 9.4 24.6 9.4 33.9 0l28.3-28.3c9.4-9.4 9.4-24.6.1-34zM208 336c-70.7 0-128-57.2-128-128 0-70.7 57.2-128 128-128 70.7 0 128 57.2 128 128 0 70.7-57.2 128-128 128z"
    );
    const hamburgerIcon = new Path2D(
      "M16 132h416c8.837 0 16-7.163 16-16V76c0-8.837-7.163-16-16-16H16C7.163 60 0 67.163 0 76v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16z"
    );
    const chatIcon = new Path2D(
      "M512 240c0 114.9-114.6 208-256 208c-37.1 0-72.3-6.4-104.1-17.9c-11.9 8.7-31.3 20.6-54.3 30.6C73.6 471.1 44.7 480 16 480c-6.5 0-12.3-3.9-14.8-9.9c-2.5-6-1.1-12.8 3.4-17.4c0 0 0 0 0 0s0 0 0 0s0 0 0 0c0 0 0 0 0 0l.3-.3c.3-.3 .7-.7 1.3-1.4c1.1-1.2 2.8-3.1 4.9-5.7c4.1-5 9.6-12.4 15.2-21.6c10-16.6 19.5-38.4 21.4-62.9C17.7 326.8 0 285.1 0 240C0 125.1 114.6 32 256 32s256 93.1 256 208z"
    );
    ctx.save(); // Save the previous state for translation and scale
    ctx.translate(
      this.width - avatarSize * 2 - headerMargin * 0.5,
      avatarSize / 2
    );
    // need to scale paths otherwise they're too large
    ctx.scale(pathScale, pathScale);
    ctx.fill(searchIcon);
    ctx.restore();
    ctx.save();
    ctx.translate(
      this.width - avatarSize * 3 - headerMargin * 0.5,
      avatarSize / 2
    );
    ctx.scale(pathScale, pathScale);
    ctx.fill(chatIcon);
    ctx.restore();
    ctx.save();
    ctx.translate(headerMargin * 1.75, avatarSize / 2);
    ctx.scale(pathScale, pathScale);
    ctx.fill(hamburgerIcon);
    ctx.restore();
  }

  drawPills(colors, font, headerHeight, opts) {
    opts = opts || {};

    const { ctx } = this;

    const badgeHeight = headerHeight * 2 * 0.25;
    const headerMargin = headerHeight * 0.2;
    const fontSize = Math.round(badgeHeight * 0.5);
    ctx.font = `${fontSize}px '${font}'`;

    const allCategoriesText = i18n(
      "wizard.homepage_preview.nav_buttons.all_categories"
    );
    const categoriesWidth = ctx.measureText(allCategoriesText).width;
    const categoriesBoxWidth = categoriesWidth + headerMargin * 2;

    // Box around "all categories >"
    ctx.beginPath();
    ctx.strokeStyle = colors.primary;
    ctx.lineWidth = 0.5;
    ctx.rect(
      headerMargin,
      headerHeight + headerMargin,
      categoriesBoxWidth,
      badgeHeight
    );
    ctx.stroke();

    ctx.fillStyle = colors.primary;
    ctx.fillText(
      allCategoriesText,
      headerMargin * 1.5,
      headerHeight + headerMargin * 1.4 + fontSize
    );

    // Caret (>) at the end of "all categories" box
    const pathScale = badgeHeight / 1000;
    const caretIcon = new Path2D(
      "M0 384.662V127.338c0-17.818 21.543-26.741 34.142-14.142l128.662 128.662c7.81 7.81 7.81 20.474 0 28.284L34.142 398.804C21.543 411.404 0 402.48 0 384.662z"
    );

    ctx.save();
    ctx.translate(
      categoriesBoxWidth,
      headerHeight + headerMargin + badgeHeight / 4
    );
    ctx.scale(pathScale, pathScale);
    ctx.fill(caretIcon);
    ctx.restore();

    const categoryHomepage =
      opts.homepageStyle !== "hot" && opts.homepageStyle !== "latest";

    // First top menu item
    let otherHomepageText;
    switch (opts.homepageStyle) {
      case "hot":
        otherHomepageText = i18n("wizard.homepage_preview.nav_buttons.hot");
        break;
      case "latest":
        otherHomepageText = i18n("wizard.homepage_preview.nav_buttons.latest");
        break;
    }

    const firstTopMenuItemText = categoryHomepage
      ? i18n("wizard.homepage_preview.nav_buttons.categories")
      : otherHomepageText;

    const newText = i18n("wizard.homepage_preview.nav_buttons.new");
    const unreadText = i18n("wizard.homepage_preview.nav_buttons.unread");
    const topText = i18n("wizard.homepage_preview.nav_buttons.top");

    ctx.beginPath();
    ctx.fillStyle = colors.tertiary;
    ctx.rect(
      categoriesBoxWidth + headerMargin * 2,
      headerHeight + headerMargin,
      ctx.measureText(firstTopMenuItemText).width + headerMargin * 2,
      badgeHeight
    );
    ctx.fill();

    ctx.font = `${fontSize}px '${font}'`;
    ctx.fillStyle = colors.secondary;
    const pillButtonTextY = headerHeight + headerMargin * 1.4 + fontSize;
    const firstTopMenuItemX = headerMargin * 3.0 + categoriesBoxWidth;
    ctx.fillText(
      firstTopMenuItemText,
      firstTopMenuItemX,
      pillButtonTextY,
      ctx.measureText(firstTopMenuItemText).width
    );

    ctx.fillStyle = colors.primary;

    const newTextX =
      firstTopMenuItemX +
      ctx.measureText(firstTopMenuItemText).width +
      headerMargin * 2.0;
    ctx.fillText(newText, newTextX, pillButtonTextY);

    const unreadTextX =
      newTextX + ctx.measureText(newText).width + headerMargin * 2.0;
    ctx.fillText(unreadText, unreadTextX, pillButtonTextY);

    const topTextX =
      unreadTextX + ctx.measureText(unreadText).width + headerMargin * 2.0;
    ctx.fillText(topText, topTextX, pillButtonTextY);
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
