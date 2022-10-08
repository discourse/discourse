import { loadSprites } from "discourse/lib/svg-sprite-loader";

export default {
  name: "svg-sprite-fontawesome",
  after: "discourse-bootstrap",

  initialize(container) {
    let session = container.lookup("service:session");
    if (session.svgSpritePath) {
      loadSprites(session.svgSpritePath, "fontawesome");
    }
  },
};
