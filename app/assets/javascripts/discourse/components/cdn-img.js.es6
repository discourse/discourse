import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",
  width: null,
  height: null,

  @computed("width", "height")
  widthRatio(width, height) {
    if (width && height) {
      return width / height;
    }
  },

  @computed("width", "height")
  heightRatio(width, height) {
    if (width && height) {
      return height / width;
    }
  },

  @computed("widthRatio", "heightRatio")
  style(widthRatio, heightRatio) {
    return;
    if (widthRatio || heightRatio) {
      let text = [];

      if (widthRatio) {
        text.push(`--width-ratio:${widthRatio};`);
      }
      
      if (heightRatio) {
        text.push(`--height-ratio:${heightRatio};`);
      }

      return text.join(" ");
    }
  },

  @computed("src")
  cdnSrc(src) {
    return Discourse.getURLWithCDN(src);
  }
});
