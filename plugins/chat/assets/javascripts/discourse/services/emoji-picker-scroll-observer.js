import Service, { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class EmojiPickerScrollObserver extends Service {
  @service chatEmojiPickerManager;

  @tracked enabled = true;
  direction = "up";
  prevYPosition = 0;

  @bind
  _observerCallback(event) {
    if (!this.enabled) {
      return;
    }

    this._setScrollDirection(event.target);

    const visibleSections = [
      ...document.querySelectorAll(".chat-emoji-picker__section"),
    ].filter((sectionElement) =>
      this._isSectionVisibleInPicker(sectionElement, event.target)
    );

    if (visibleSections?.length) {
      let sectionElement;

      if (this.direction === "up" || this.prevYPosition < 50) {
        sectionElement = visibleSections.firstObject;
      } else {
        sectionElement = visibleSections.lastObject;
      }

      this.chatEmojiPickerManager.lastVisibleSection =
        sectionElement.dataset.section;

      this.chatEmojiPickerManager.addVisibleSections(
        visibleSections.map((s) => s.dataset.section)
      );
    }
  }

  observe(element) {
    element.addEventListener("scroll", this._observerCallback);
  }

  unobserve(element) {
    element.removeEventListener("scroll", this._observerCallback);
  }

  _setScrollDirection(target) {
    if (target.scrollTop > this.prevYPosition) {
      this.direction = "down";
    } else {
      this.direction = "up";
    }

    this.prevYPosition = target.scrollTop;
  }

  _isSectionVisibleInPicker(section, picker) {
    const { bottom, height, top } = section.getBoundingClientRect();
    const containerRect = picker.getBoundingClientRect();

    return top <= containerRect.top
      ? containerRect.top - top <= height
      : bottom - containerRect.bottom <= height;
  }
}
