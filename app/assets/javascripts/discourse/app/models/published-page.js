import RestModel from "discourse/models/rest";
import { computed } from "@ember/object";

export default RestModel.extend({
  url: computed("slug", function() {
    return `${Discourse.BaseUrl}/pub/${this.slug}`;
  })
});
