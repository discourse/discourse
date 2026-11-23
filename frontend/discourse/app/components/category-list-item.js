import Component from "@glimmer/component";
import { service } from "@ember/service";
import categoryListSubcategories, {
  hasGrandchildren,
} from "discourse/helpers/category-list-subcategories";
import { applyValueTransformer } from "discourse/lib/transformer";

const LIST_TYPE = {
  NORMAL: "normal",
  MUTED: "muted",
};

export default class CategoryListItem extends Component {
  @service discovery;

  /** @returns {import("discourse/models/category").default | null | undefined} */
  get category() {
    return this.args.category;
  }

  get listType() {
    return this.args.listType ?? LIST_TYPE.NORMAL;
  }

  get isHidden() {
    return (
      (this.category?.isHidden && this.listType === LIST_TYPE.NORMAL) ||
      (!this.category?.hasMuted && this.listType === LIST_TYPE.MUTED)
    );
  }

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

  get slugPath() {
    return this.category?.path?.substring("/c/".length);
  }

  get page() {
    return this.args.categoryListPage ?? this.discovery.categoryListPage;
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
