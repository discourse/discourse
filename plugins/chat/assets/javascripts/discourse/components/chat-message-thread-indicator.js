import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { escapeExpression } from "discourse/lib/utilities";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class ChatMessageThreadIndicator extends Component {
  @service capabilities;
  @service chat;
  @service chatStateManager;
  @service router;
  @service site;

  @tracked isActive = false;

  @action
  setup(element) {
    this.element = element;

    if (this.capabilities.touch) {
      this.element.addEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.addEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.addEventListener("touchend", this.onTouchEnd);
      this.element.addEventListener("touchCancel", this.cancelTouch);
    }

    this.element.addEventListener("click", this.openThread, {
      passive: true,
    });
  }

  @action
  teardown() {
    if (this.capabilities.touch) {
      this.element.removeEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.removeEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.removeEventListener("touchend", this.onTouchEnd);
      this.element.removeEventListener("touchCancel", this.cancelTouch);
    }

    this.element.removeEventListener("click", this.openThread, {
      passive: true,
    });
  }

  @bind
  onTouchStart(event) {
    this.isActive = true;
    event.stopPropagation();

    this.touching = true;
  }

  @bind
  onTouchEnd() {
    this.isActive = false;

    if (this.touching) {
      this.openThread();
    }
  }

  @bind
  cancelTouch() {
    this.isActive = false;
    this.touching = false;
  }

  @bind
  openThread() {
    this.chat.activeMessage = null;

    this.router.transitionTo(
      "chat.channel.thread",
      ...this.args.message.thread.routeModels
    );
  }

  get threadTitle() {
    return escapeExpression(this.args.message.threadTitle);
  }
}
