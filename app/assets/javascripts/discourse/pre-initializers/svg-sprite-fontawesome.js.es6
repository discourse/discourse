import svgSpriteLoader from "discourse/lib/svg-sprite-loader";

export default {
  name: "svg-sprite-fontawesome",

  initialize() {
    if (Discourse && Discourse.SvgSpritePath) {
      svgSpriteLoader.load(Discourse.SvgSpritePath, "fontawesome");
    }
  }
};
