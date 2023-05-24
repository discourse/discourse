import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SidebarSectionFormLink extends Component {
  @tracked dragCssClass;


  isAboveElement(event) {
    event.preventDefault();
    const target = event.currentTarget;
    const domRect = target.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragHasStarted(event) {
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("linkId", this.link.objectId);
    this.dragCssClass = "dragging";
  }
  @action
  dragOver(event) {
    event.preventDefault();
    if (!this.dragCssClass) {
      if (this.isAboveElement(event)) {
        this.dragCssClass = "drag-above";
      } else {
        this.dragCssClass = "drag-below";
      }
    }
  }
  @action
  dragLeave() {
    if (
      this.dragCssClass === "drag-above" ||
      this.dragCssClass === "drag-below"
    ) {
      this.dragCssClass = null;
    }
  }
  @action
  dropItem(event) {
    event.stopPropagation();
    this.reorderCallback(
      parseInt(event.dataTransfer.getData("linkId"), 10),
      this.link.objectId,
      this.isAboveElement(event)
    );
    this.dragCssClass = null;
  }
  @action
  dragEnd() {
    this.dragCssClass = null;
  }
}
