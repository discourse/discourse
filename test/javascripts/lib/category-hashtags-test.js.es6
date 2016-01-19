import createStore from 'helpers/create-store';
import Category from 'discourse/models/category';
import { findCategoryByHashtagSlug } from "discourse/lib/category-hashtags";

module("lib:category-hashtags");

test('findCategoryByHashtagSlug', () => {
  const store = createStore();

  const parentCategory = store.createRecord('category', { slug: 'test1' });

  const childCategory = store.createRecord('category', {
    slug: 'test2', parentCategory: parentCategory
  });

  sandbox.stub(Category, 'list').returns([parentCategory, childCategory]);

  equal(findCategoryByHashtagSlug('test1'), parentCategory, 'returns the right category');
  equal(findCategoryByHashtagSlug('test1:test2'), childCategory, 'returns the right category');
  equal(findCategoryByHashtagSlug('#test1'), parentCategory, 'returns the right category');
  equal(findCategoryByHashtagSlug('#test1:test2'), childCategory, 'returns the right category');
});
