import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

const FIRST_ID = 9_000_000;
const COLORS = ["0088CC", "E45735", "3AB54A", "F7941D", "652D90", "BF1E2E"];

/** 100 roots, 9 children each and 10 grandchildren under every child: 10,000 categories. */
function sampleCategories() {
  const categories = [];
  let id = FIRST_ID;
  const add = (path, parentId) => {
    const category = {
      id: ++id,
      name: i18n("styleguide.sections.select.large_category_list_sample", {
        path,
      }),
      slug: `sample-${id}`,
      color: COLORS[id % COLORS.length],
      text_color: "FFFFFF",
      parent_category_id: parentId,
      permission: 1,
    };
    categories.push(category);
    return category.id;
  };
  for (let root = 0; root < 100; root++) {
    const rootId = add(`${root}`);
    for (let child = 0; child < 9; child++) {
      const childId = add(`${root}-${child}`, rootId);
      for (let grandchild = 0; grandchild < 10; grandchild++) {
        add(`${root}-${child}-${grandchild}`, childId);
      }
    }
  }
  return categories;
}

/** Loads sample categories into the site on request and removes them when it goes away. */
export default class LargeCategoryListExample extends Component {
  @service site;

  @tracked loaded = false;
  @tracked value = [];

  #ids = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#unload();
  }

  @action
  load() {
    const categories = sampleCategories();
    this.site.updateCategories(categories);
    this.#ids = new Set(categories.map((category) => category.id));
    this.loaded = true;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  #unload() {
    if (!this.#ids) {
      return;
    }
    // One pass: removing 10,000 records one at a time scans the list each time.
    const kept = this.site.categories.filter(
      (category) => !this.#ids.has(category.id)
    );
    this.site.categories.splice(0, this.site.categories.length, ...kept);
    this.#ids.forEach((id) => this.site.loadedCategoryIds?.delete(id));
    this.#ids = null;
  }

  <template>
    {{#if this.loaded}}
      <DSelectCategory
        @emit="ids"
        @identifier="sg-large-category-list"
        @onChange={{this.onChange}}
        @value={{this.value}}
      />
    {{else}}
      <DButton
        @action={{this.load}}
        @label="styleguide.sections.select.large_category_list_load"
      />
    {{/if}}
  </template>
}
