import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";

export default class ReviewableFlaggedPost extends Component {
  @tracked isCollapsed = false;
  @tracked isLongPost = false;
  maxPostHeight = 300;

  @action
  toggleContent() {
    this.isCollapsed = !this.isCollapsed;
  }

  @bind
  calculatePostBodySize(element) {
    if (element?.offsetHeight > this.maxPostHeight) {
      this.isCollapsed = true;
      this.isLongPost = true;
    } else {
      this.isCollapsed = false;
      this.isLongPost = false;
    }
  }

  get collapseButtonProps() {
    if (this.isCollapsed) {
      return {
        label: "review.show_more",
        icon: "chevron-down",
      };
    }
    return {
      label: "review.show_less",
      icon: "chevron-up",
    };
  }
}
