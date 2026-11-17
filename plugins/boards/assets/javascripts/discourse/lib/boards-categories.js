import Category from "discourse/models/category";
import Site from "discourse/models/site";

export function loadCategory(id) {
  return Category.findById(id) || Category.asyncFindById(id);
}

export function loadCategories(ids = []) {
  ids = [...new Set(ids.filter(Boolean))];
  const categories = Category.findByIds(ids);

  if (
    !Site.current().lazy_load_categories ||
    categories.length === ids.length
  ) {
    return categories;
  }

  return Category.asyncFindByIds(ids);
}

export async function preloadCategories(ids) {
  try {
    await loadCategories(ids);
  } catch {}
}
