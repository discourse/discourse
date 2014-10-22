module("Discourse.HTML");

var html = Discourse.HTML;

test("categoryBadge without a category", function() {
  blank(html.categoryBadge(), "it returns no HTML");
});

test("Regular categoryBadge", function() {
  var category = Discourse.Category.create({
        name: 'hello',
        id: 123,
        description_text: 'cool description',
        color: 'ff0',
        text_color: 'f00'
      }),
      tag = parseHTML(html.categoryBadge(category))[0];

  equal(tag.name, 'a', 'it creates an `a` tag');
  equal(tag.attributes['class'], 'badge-category', 'it has the correct class');
  equal(tag.attributes.title, 'cool description', 'it has the correct title');

  ok(tag.attributes.style.indexOf('#ff0') !== -1, "it has the color style");
  ok(tag.attributes.style.indexOf('#f00') !== -1, "it has the textColor style");

  equal(tag.children[0].data, 'hello', 'it has the category name');
});

test("undefined color", function() {
  var noColor = Discourse.Category.create({ name: 'hello', id: 123 }),
      tag = parseHTML(html.categoryBadge(noColor))[0];

  blank(tag.attributes.style, "it has no color style because there are no colors");
});

test("allowUncategorized", function() {
  var uncategorized = Discourse.Category.create({name: 'uncategorized', id: 345});
  sandbox.stub(Discourse.Site, 'currentProp').withArgs('uncategorized_category_id').returns(345);

  blank(html.categoryBadge(uncategorized), "it doesn't return HTML for uncategorized by default");
  present(html.categoryBadge(uncategorized, {allowUncategorized: true}), "it returns HTML");
});


test("customHTML", function() {
  blank(html.getCustomHTML('evil'), "there is no custom HTML for a key by default");

  html.setCustomHTML('evil', 'trout');
  equal(html.getCustomHTML('evil'), 'trout', 'it retrieves the custom html');

  PreloadStore.store('customHTML', {cookie: 'monster'});
  equal(html.getCustomHTML('cookie'), 'monster', 'it returns HTML fragments from the PreloadStore');

});
