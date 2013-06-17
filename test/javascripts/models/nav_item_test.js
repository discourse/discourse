/*global module:true test:true ok:true visit:true expect:true exists:true count:true equal:true */

module("Discourse.NavItem", {
  setup: function() {
    this.site = Discourse.Site.instance();
    this.originalCategories = Discourse.Site.instance().get('categories') || [];
    this.site.set('categories', this.originalCategories.concat( [Discourse.Category.create({name: '确实是这样', id: 343434})] ));
  },

  teardown: function() {
    this.site.set('categories', this.originalCategories);
  }
});

test('href', function(){
  expect(4);

  equal(Discourse.NavItem.fromText('latest', {}).get('href'), '/latest', "latest");
  equal(Discourse.NavItem.fromText('categories', {}).get('href'), '/categories', "categories");
  equal(Discourse.NavItem.fromText('category/bug', {}).get('href'), '/category/bug', "English category name");
  equal(Discourse.NavItem.fromText('category/确实是这样', {}).get('href'), '/category/343434-category', "Chinese category name");
});
