import { queryParams } from "discourse/controllers/discovery-sortable";
import { buildTagRoute } from "discourse/routes/tag-show";

// The tags-intersection route is exactly the same as the tags-show route, but the wildcard at the
// end of the route (*additional_tags) will cause a match when query parameters are present,
// breaking all other tags-show routes. Ember thinks the query params are addition tags and should
// be handled by the intersection logic. Defining tags-intersection as something separate avoids
// that confusion.
export default buildTagRoute().extend({
  controllerName: "tags.intersection",

  init() {
    this._super(...arguments);

    // The only difference is support for `category` query param.
    // Other routes include category in the route path.
    this.set("queryParams", { ...queryParams });
    this.queryParams["categoryParam"] = { replace: true, refreshModel: true };
  },
});
