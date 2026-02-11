/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { applyValueTransformer } from "discourse/lib/transformer";

const LIST_TYPE = {
  NORMAL: "normal",
  MUTED: "muted",
};

@tagName("")
export default class CategoryListItem extends Component {
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

  applyValueTransformer(name, value, context) {
    return applyValueTransformer(name, value, context);
  }
}
