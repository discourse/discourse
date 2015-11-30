import { decorateCooked } from "discourse/lib/plugin-api";

export default {
  name: "apply-details",

  initialize(container) {
    decorateCooked(container, $elem => $("details", $elem).details());
  }

};
