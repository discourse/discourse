import loadMorphlex from "discourse/lib/load-morphlex";
import { withPluginApi } from "discourse/lib/plugin-api";
import { cook } from "discourse/lib/text";
import { addProgressDot } from "../progress-handlers";
import StreamUpdater from "./stream-updater";

export default class PostUpdater extends StreamUpdater {
  morphingOptions = {
    beforeAttributeUpdated: (element, attributeName) => {
      return !(element.tagName === "DETAILS" && attributeName === "open");
    },
  };

  constructor(postStream, postId) {
    super();

    this.postStream = postStream;
    this.postId = postId;
    this.post = postStream.findLoadedPost(postId);
    const topicId = postStream.topic.id;

    if (this.post) {
      this.postElement = document.querySelector(
        `.topic-area[data-topic-id="${topicId}"] #post_${this.post.post_number}`
      );
    }
  }

  get element() {
    return this.postElement;
  }

  set streaming(value) {
    if (this.postElement) {
      if (value) {
        this.postElement.classList.add("streaming");
      } else {
        this.postElement.classList.remove("streaming");
      }
    }
  }

  async setRaw(value, done) {
    this.post.set("raw", value);
    const cooked = await cook(value);

    // resets animation
    this.element.classList.remove("streaming");
    void this.element.offsetWidth;
    this.element.classList.add("streaming");

    const cookedElement = document.createElement("div");
    cookedElement.innerHTML = cooked;

    if (!done) {
      addProgressDot(cookedElement);
    }

    await this.setCooked(cookedElement.innerHTML, done);
  }

  async setCooked(value, done) {
    if (!this.postElement) {
      return;
    }

    withPluginApi((api) => api.preventCloak(this.postId));

    (await loadMorphlex()).morphInner(
      this.postElement.querySelector(".cooked"),
      `<div>${value}</div>`,
      this.morphingOptions
    );

    if (done) {
      this.post.set("cooked", value);
      withPluginApi((api) => api.preventCloak(this.postId, false));
    }
  }

  get raw() {
    return this.post.get("raw") || "";
  }
}
