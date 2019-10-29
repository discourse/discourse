import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";
import { escapeExpression } from "discourse/lib/utilities";
import { convertIconClass } from "discourse-common/lib/icon-library";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  classNames: ["group-flair-inputs"],

  @computed
  demoAvatarUrl() {
    return Discourse.getURL("/images/avatar.png");
  },

  @computed("model.flair_url")
  flairPreviewIcon(flairURL) {
    return flairURL && /fa(r|b?)-/.test(flairURL);
  },

  @computed("model.flair_url", "flairPreviewIcon")
  flairPreviewIconUrl(flairURL, flairPreviewIcon) {
    return flairPreviewIcon ? convertIconClass(flairURL) : "";
  },

  @observes("model.flair_url")
  _loadSVGIcon() {
    Ember.run.debounce(this, this._loadIcon, 1000);
  },

  _loadIcon() {
    const icon = convertIconClass(this.get("model.flair_url")),
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

  @computed("model.flair_url", "flairPreviewIcon")
  flairPreviewImage(flairURL, flairPreviewIcon) {
    return flairURL && !flairPreviewIcon;
  },

  @computed(
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

    return Ember.String.htmlSafe(style);
  },

  @computed("model.flairBackgroundHexColor")
  flairPreviewClasses(flairBackgroundHexColor) {
    if (flairBackgroundHexColor) return "rounded";
  },

  @computed("flairPreviewImage")
  flairPreviewLabel(flairPreviewImage) {
    const key = flairPreviewImage ? "image" : "icon";
    return I18n.t(`groups.flair_preview_${key}`);
  }
});
