import componentTest from 'helpers/component-test';
// import Category from 'discourse/models/category';
//
// const buildCategory = function(name, parent_category_id, color, text_color) {
//   return Category.create({
//     name,
//     color,
//     text_color,
//     parent_category_id,
//     read_restricted: false
//   });
// };

moduleForComponent('category-select-box', {integration: true});

componentTest('with default configuration', {
  template: '{{category-select-box}}',
  beforeEach() {
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      console.log(this.$(".header").html());
      assert.equal(this.$(".filter").length, 1, "it is filterable");
    });
  }
});
