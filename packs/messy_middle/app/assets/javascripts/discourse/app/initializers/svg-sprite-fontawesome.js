import { loadSprites } from "discourse/lib/svg-sprite-loader";

export default {
  name: "svg-sprite-fontawesome",
  after: "export-application-global",

  initialize(container) {
    const session = container.lookup("service:session");

    if (session.svgSpritePath) {
      loadSprites(session.svgSpritePath, "fontawesome");
    }
  },
};
