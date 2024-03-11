import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RawEmailModal from "discourse/components/modal/raw-email";

export default class ReviewableQueuedPost extends Component {
  @service modal;

  @tracked isCollapsed = false;
  @tracked isLongPost = false;
  @tracked postBodyHeight = 0;
  maxPostHeight = 300;

  @action
  showRawEmail(event) {
    event?.preventDefault();
    this.modal.show(RawEmailModal, {
      model: {
        rawEmail: this.args.reviewable.payload.raw_email,
      },
    });
  }

  @action
  toggleContent() {
    this.isCollapsed = !this.isCollapsed;
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

  @action
  setPostBodyHeight(offsetHeight) {
    this.postBodyHeight = offsetHeight;

    if (this.postBodyHeight > this.maxPostHeight) {
      this.isCollapsed = true;
      this.isLongPost = true;
    } else {
      this.isCollapsed = false;
      this.isLongPost = false;
    }
  }
}
