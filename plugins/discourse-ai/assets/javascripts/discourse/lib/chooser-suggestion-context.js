import { getOwner } from "@ember/owner";
import {
  MIN_CHARACTER_COUNT,
  tagSuggestionParams,
} from "./ai-helper-suggestions";

function tagNames(tags) {
  return (tags ?? [])
    .map((tag) => (typeof tag === "string" ? tag : tag?.name))
    .filter(Boolean);
}

class ComposerSuggestionContext {
  constructor(composer) {
    this.composer = composer;
  }

  get model() {
    return this.composer.model;
  }

  get categoryChooserEnabled() {
    return !this.composer.disableCategoryChooser;
  }

  get tagChooserEnabled() {
    return !this.composer.disableTagsChooser;
  }

  get selectedTagNames() {
    return tagNames(this.composer.model?.tags);
  }

  get available() {
    return (this.model?.reply?.length ?? 0) > MIN_CHARACTER_COUNT;
  }

  categoryRequestData() {
    const text = this.model?.reply;
    if (!text || text.length < MIN_CHARACTER_COUNT) {
      return null;
    }
    return { text };
  }

  tagRequestData() {
    const text = this.model?.reply;
    if (!text || text.length < MIN_CHARACTER_COUNT) {
      return null;
    }
    return {
      text,
      ...tagSuggestionParams(this.model.categoryId, this.model.tags),
    };
  }
}

class EditTopicSuggestionContext {
  constructor(topicController) {
    this.topicController = topicController;
  }

  get model() {
    return { privateMessage: this.topicController.model?.isPrivateMessage };
  }

  get categoryChooserEnabled() {
    return true;
  }

  get tagChooserEnabled() {
    return true;
  }

  get selectedTagNames() {
    return tagNames(this.topicController.model?.tags);
  }

  get available() {
    return true;
  }

  categoryRequestData() {
    return { topic_id: this.topicController.model.id };
  }

  tagRequestData() {
    return { topic_id: this.topicController.model.id };
  }
}

export function chooserSuggestionContext(component) {
  const owner = getOwner(component);
  const element = component.element;

  if (element?.closest("#reply-control")) {
    const composer = owner.lookup("service:composer");
    if (composer?.model) {
      return new ComposerSuggestionContext(composer);
    }
  }

  if (element?.closest(".edit-topic-title")) {
    const topicController = owner.lookup("controller:topic");
    if (topicController?.editingTopic && topicController.model) {
      return new EditTopicSuggestionContext(topicController);
    }
  }

  return null;
}
