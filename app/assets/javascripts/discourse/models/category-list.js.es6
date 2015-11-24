const CategoryList = Ember.ArrayProxy.extend({
  init() {
    this.set('content', []);
    this._super();
  }
});

CategoryList.reopenClass({
  categoriesFrom(store, result) {
    const categories = CategoryList.create();
    const users = Discourse.Model.extractByKey(result.featured_users, Discourse.User);
    const list = Discourse.Category.list();

    result.category_list.categories.forEach(c => {
      if (c.parent_category_id) {
        c.parentCategory = list.findBy('id', c.parent_category_id);
      }

      if (c.subcategory_ids) {
        c.subcategories = c.subcategory_ids.map(scid => list.findBy('id', parseInt(scid, 10)));
      }

      if (c.featured_user_ids) {
        c.featured_users = c.featured_user_ids.map(u => users[u]);
      }

      if (c.topics) {
        c.topics = c.topics.map(t => Discourse.Topic.create(t));
      }

      categories.pushObject(store.createRecord('category', c));
    });
    return categories;
  },

  listForParent(store, category) {
    return Discourse.ajax(`/categories.json?parent_category_id=${category.get("id")}`).then(result => {
      return CategoryList.create({
        categories: this.categoriesFrom(store, result),
        parentCategory: category
      });
    });
  },

  list(store) {
    const getCategories = () => Discourse.ajax("/categories.json");
    return PreloadStore.getAndRemove("categories_list", getCategories).then(result => {
      return CategoryList.create({
        categories: this.categoriesFrom(store, result),
        can_create_category: result.category_list.can_create_category,
        can_create_topic: result.category_list.can_create_topic,
        draft_key: result.category_list.draft_key,
        draft: result.category_list.draft,
        draft_sequence: result.category_list.draft_sequence
      });
    });
  }
});

export default CategoryList;
