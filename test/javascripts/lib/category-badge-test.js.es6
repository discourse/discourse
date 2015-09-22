import createStore from 'helpers/create-store';
import { blank, present } from 'helpers/qunit-helpers';

module("lib:category-link");

import parseHTML from 'helpers/parse-html';
import { categoryBadgeHTML } from "discourse/helpers/category-link";

test("categoryBadge without a category", function() {
  blank(categoryBadgeHTML(), "it returns no HTML");
});

test("Regular categoryBadge", function() {
  const store = createStore();
  const category = store.createRecord('category', {
          name: 'hello',
          id: 123,
          description_text: 'cool description',
          color: 'ff0',
          text_color: 'f00'
        });
  const tag = parseHTML(categoryBadgeHTML(category))[0];

  equal(tag.name, 'a', 'it creates a `a` wrapper tag');
  equal(tag.attributes['class'].trim(), 'badge-wrapper', 'it has the correct class');

  const label = tag.children[1];
  equal(label.attributes.title, 'cool description', 'it has the correct title');

  equal(label.children[0].data, 'hello', 'it has the category name');
});

test("undefined color", function() {
  const store = createStore();
  const noColor = store.createRecord('category', { name: 'hello', id: 123 });
  const tag = parseHTML(categoryBadgeHTML(noColor))[0];

  blank(tag.attributes.style, "it has no color style because there are no colors");
});

test("allowUncategorized", function() {
  const store = createStore();
  const uncategorized = store.createRecord('category', {name: 'uncategorized', id: 345});
  sandbox.stub(Discourse.Site, 'currentProp').withArgs('uncategorized_category_id').returns(345);

  blank(categoryBadgeHTML(uncategorized), "it doesn't return HTML for uncategorized by default");
  present(categoryBadgeHTML(uncategorized, {allowUncategorized: true}), "it returns HTML");
});
