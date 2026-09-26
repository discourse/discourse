import { lookup } from "discourse/lib/service";
import { loadSprites } from "discourse/lib/svg-sprite-loader";
import SessionService from "discourse/services/session";

export default {
  initialize(owner) {
    const session = lookup(owner, SessionService);

    if (session.svgSpritePath) {
      loadSprites(session.svgSpritePath, "fontawesome");
    }
  },
};
