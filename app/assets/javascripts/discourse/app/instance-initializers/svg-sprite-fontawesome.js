import { loadSprites } from "discourse/lib/svg-sprite-loader";

export default {
  initialize(owner) {
    const session = owner.lookup("service:session");

    if (session.svgSpritePath) {
      loadSprites(session.svgSpritePath, "fontawesome");
    }
  },
};
