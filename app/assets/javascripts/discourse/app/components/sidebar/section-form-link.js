import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";

export default class SectionFormLink extends Component {
  @service site;
  @tracked dragCssClass;

  dragCount = 0;

  isAboveElement(event) {
    event.preventDefault();
    const target = event.currentTarget;
    const domRect = target.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragHasStarted(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.setDraggedLinkCallback(this.args.link);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    event.preventDefault();
    if (this.dragCssClass !== "dragging") {
      if (this.isAboveElement(event)) {
        this.dragCssClass = "drag-above";
      } else {
        this.dragCssClass = "drag-below";
      }
    }
  }
  @action
  dragEnter() {
    this.dragCount++;
  }

  @action
  dragLeave() {
    this.dragCount--;
    if (
      this.dragCount === 0 &&
      (this.dragCssClass === "drag-above" || this.dragCssClass === "drag-below")
    ) {
      discourseLater(() => {
        this.dragCssClass = null;
      }, 10);
    }
  }

  @action
  dropItem(event) {
    event.stopPropagation();
    this.dragCount = 0;
    this.args.reorderCallback(this.args.link, this.isAboveElement(event));
    this.dragCssClass = null;
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
  }
}
