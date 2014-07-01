import AddCategoryClass from 'discourse/mixins/add-category-class';

export default Em.View.extend(AddCategoryClass, {
  categoryId: Em.computed.alias('controller.category.id'),
});
