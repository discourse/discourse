/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import categoryListSubcategories, {
  hasGrandchildren,
} from "discourse/helpers/category-list-subcategories";
import { applyValueTransformer } from "discourse/lib/transformer";

const LIST_TYPE = {
  NORMAL: "normal",
  MUTED: "muted",
};

@tagName("")
export default class CategoryListItem extends Component {
  @service discovery;

  category = null;
  listType = LIST_TYPE.NORMAL;

  @computed("category.isHidden", "category.hasMuted", "listType")
  get isHidden() {
    return (
      (this.category?.isHidden && this.listType === LIST_TYPE.NORMAL) ||
      (!this.category?.hasMuted && this.listType === LIST_TYPE.MUTED)
    );
  }

  @computed("category.isMuted", "listType")
  get isMuted() {
    return (
      (this.category?.isMuted && this.listType === LIST_TYPE.NORMAL) ||
      (!this.category?.isMuted && this.listType === LIST_TYPE.MUTED)
    );
  }

  get unreadTopicsCount() {
    return this.category.unreadTopicsCount;
  }

  get newTopicsCount() {
    return this.category.newTopicsCount;
  }

  @computed("category.path")
  get slugPath() {
    return this.category?.path?.substring("/c/".length);
  }

  get page() {
    return this.categoryListPage ?? this.discovery.categoryListPage;
  }

  get displayedSubcategories() {
    return categoryListSubcategories(this.category, { page: this.page });
  }

  get showsGrandchildren() {
    return hasGrandchildren(this.displayedSubcategories, { page: this.page });
  }

  applyValueTransformer(name, value, context) {
    return applyValueTransformer(name, value, context);
  }
}
