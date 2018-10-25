import svgSpriteLoader from "discourse/lib/svg-sprite-loader";

export default {
  name: "svg-sprite-fontawesome",

  initialize() {
    svgSpriteLoader.load(Discourse.SvgSpritePath, "fontawesome");
  }
};
