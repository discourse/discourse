import Component from "@ember/component";
import { and } from "@ember/object/computed";

export default Component.extend({
  shouldShow: and("category.read_only_banner", "readOnly", "user")
});
