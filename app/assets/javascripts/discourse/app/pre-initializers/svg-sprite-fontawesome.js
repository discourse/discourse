import { loadSprites } from "discourse/lib/svg-sprite-loader";

export default {
  name: "svg-sprite-fontawesome",

  initialize(container) {
    let session = container.lookup("session:main");
    if (session.svgSpritePath) {
      loadSprites(session.svgSpritePath, "fontawesome");
    }
  }
};
