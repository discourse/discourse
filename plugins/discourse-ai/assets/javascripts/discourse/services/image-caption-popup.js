import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { IMAGE_MARKDOWN_REGEX } from "discourse/lib/uploads";

export default class ImageCaptionPopup extends Service {
  @service composer;
  @service appEvents;

  @tracked showPopup = false;
  @tracked imageIndex = null;
  @tracked imageSrc = null;
  @tracked newCaption = null;
  @tracked loading = false;
  @tracked popupTrigger = null;
  @tracked showAutoCaptionLoader = false;
  @tracked _request = null;

  updateCaption() {
    const matchingPlaceholder =
      this.composer.model.reply.match(IMAGE_MARKDOWN_REGEX);

    if (matchingPlaceholder) {
      const match = matchingPlaceholder[this.imageIndex];
      const replacement = match.replace(
        IMAGE_MARKDOWN_REGEX,
        `![${this.newCaption}|$2$3$4]($5)`
      );

      if (match) {
        this.appEvents.trigger("composer:replace-text", match, replacement);
      }
    }
  }

  toggleLoadingState(loading) {
    if (loading) {
      this.popupTrigger?.classList.add("disabled");
      return (this.loading = true);
    }

    this.popupTrigger?.classList.remove("disabled");
    return (this.loading = false);
  }
}
