import Category from "discourse/models/category";

export default Discourse.DiscoveryCategoryRoute.extend({
  model(params) {
    return { category: Category.findById(params.id) };
  }
});
