import AddCategoryClass from 'discourse/mixins/add-category-class';

export default Em.View.extend(AddCategoryClass, {
  categorySlug: Em.computed.alias('controller.category.slug')
});
