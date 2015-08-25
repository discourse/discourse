import AddCategoryClass from 'discourse/mixins/add-category-class';

export default Em.View.extend(AddCategoryClass, {
  categoryFullSlug: Em.computed.alias('controller.category.fullSlug')
});
