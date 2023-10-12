import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { getAbsoluteURL } from "discourse-common/lib/get-url";

export default RestModel.extend({
  url: computed("slug", function () {
    return getAbsoluteURL(`/pub/${this.slug}`);
  }),
});
