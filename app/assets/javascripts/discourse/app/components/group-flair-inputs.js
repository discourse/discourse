import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { debounce } from "@ember/runloop";
import Component from "@ember/component";
import { on, observes } from "discourse-common/utils/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import { convertIconClass } from "discourse-common/lib/icon-library";
import { ajax } from "discourse/lib/ajax";
import { htmlSafe } from "@ember/template";
import { action } from "@ember/object";

export default Component.extend({
  classNames: ["group-flair-inputs"],

  @discourseComputed
  demoAvatarUrl() {
    return getURL("/images/avatar.png");
  },

  @discourseComputed("model.flair_type")
  flairPreviewIcon(flairType) {
    return flairType && flairType === "icon";
  },

  @discourseComputed("model.flair_icon")
  flairPreviewIconUrl(flairIcon) {
    return flairIcon ? convertIconClass(flairIcon) : "";
  },

  @on("didInsertElement")
  @observes("model.flair_icon")
  _loadSVGIcon(flairIcon) {
    if (flairIcon) {
      debounce(this, this._loadIcon, 1000);
    }
  },

  _loadIcon() {
    const icon = convertIconClass(this.model.flair_icon),
      c = "#svg-sprites",
      h = "ajax-icon-holder",
      singleIconEl = `${c} .${h}`;

    if (!icon) return;

    if (!$(`${c} symbol#${icon}`).length) {
      ajax(`/svg-sprite/search/${icon}`).then(function(data) {
        if ($(singleIconEl).length === 0) $(c).append(`<div class="${h}">`);

        $(singleIconEl).html(
          `<svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>${data}</svg>`
        );
      });
    }
  },

  @discourseComputed("model.flair_type")
  flairPreviewImage(flairType) {
    return flairType && flairType === "image";
  },

  @discourseComputed("model.flair_url")
  flairImageUrl(flairURL) {
    return flairURL && flairURL.match(/\//) ? flairURL : null;
  },

  @discourseComputed(
    "model.flair_url",
    "flairPreviewImage",
    "model.flairBackgroundHexColor",
    "model.flairHexColor"
  )
  flairPreviewStyle(
    flairURL,
    flairPreviewImage,
    flairBackgroundHexColor,
    flairHexColor
  ) {
    let style = "";

    if (flairPreviewImage) {
      style += `background-image: url(${escapeExpression(flairURL)});`;
    }

    if (flairBackgroundHexColor) {
      style += `background-color: #${flairBackgroundHexColor};`;
    }

    if (flairHexColor) style += `color: #${flairHexColor};`;

    return htmlSafe(style);
  },

  @discourseComputed("model.flairBackgroundHexColor")
  flairPreviewClasses(flairBackgroundHexColor) {
    if (flairBackgroundHexColor) return "rounded";
  },

  @discourseComputed("flairPreviewImage")
  flairPreviewLabel(flairPreviewImage) {
    const key = flairPreviewImage ? "image" : "icon";
    return I18n.t(`groups.flair_preview_${key}`);
  },

  @action
  setFlairImage(upload) {
    this.model.setProperties({
      flair_url: getURL(upload.url),
      flair_upload_id: upload.id
    });
  },

  @action
  removeFlairImage() {
    this.model.setProperties({
      flair_url: null,
      flair_upload_id: null
    });
  }
});
