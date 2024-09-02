import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";

const LIST_TYPE = {
  NORMAL: "normal",
  MUTED: "muted",
};

@tagName("")
export default class CategoryListItem extends Component {
  category = null;
  listType = LIST_TYPE.NORMAL;

  @discourseComputed("category.isHidden", "category.hasMuted", "listType")
  isHidden(isHiddenCategory, hasMuted, listType) {
    return (
      (isHiddenCategory && listType === LIST_TYPE.NORMAL) ||
      (!hasMuted && listType === LIST_TYPE.MUTED)
    );
  }

  @discourseComputed("category.isMuted", "listType")
  isMuted(isMutedCategory, listType) {
    return (
      (isMutedCategory && listType === LIST_TYPE.NORMAL) ||
      (!isMutedCategory && listType === LIST_TYPE.MUTED)
    );
  }

  @discourseComputed("topicTrackingState.messageCount")
  unreadTopicsCount() {
    return this.category.unreadTopicsCount;
  }

  @discourseComputed("topicTrackingState.messageCount")
  newTopicsCount() {
    return this.category.newTopicsCount;
  }

  @discourseComputed("category.path")
  slugPath(categoryPath) {
    return categoryPath.substring("/c/".length);
  }
}
