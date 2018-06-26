import computed from "ember-addons/ember-computed-decorators";
import { escapeExpression } from "discourse/lib/utilities";

export default Ember.Component.extend({
  classNames: ["group-flair-inputs"],

  @computed
  demoAvatarUrl() {
    return Discourse.getURL("/images/avatar.png");
  },

  @computed("model.flair_url")
  flairPreviewIcon(flairURL) {
    return flairURL && flairURL.substr(0, 3) === "fa-";
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
