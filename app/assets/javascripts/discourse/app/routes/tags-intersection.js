import TagsShowRoute from "discourse/routes/tags-show";

export default TagsShowRoute.extend({});

// The tags-intersection route is exactly the same as the tags-show route, but the wildcard at the
// end of the route (*additional_tags) will cause a match when query parameters are present,
// breaking all other tags-show routes. Ember thinks the query params are addition tags and should
// be handled by the intersection logic. Defining tags-intersection as something separate avoids
// that confusion.
