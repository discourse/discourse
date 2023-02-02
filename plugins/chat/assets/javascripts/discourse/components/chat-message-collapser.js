import Component from "@ember/component";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import domFromString from "discourse-common/lib/dom-from-string";
import I18n from "I18n";

export default class ChatMessageCollapser extends Component {
  tagName = "";
  collapsed = false;
  uploads = null;
  cooked = null;

  @computed("uploads")
  get hasUploads() {
    return hasUploads(this.uploads);
  }

  @computed("uploads")
  get uploadsHeader() {
    let name = "";
    if (this.uploads.length === 1) {
      name = this.uploads[0].original_filename;
    } else {
      name = I18n.t("chat.uploaded_files", { count: this.uploads.length });
    }
    return htmlSafe(
      `<span class="chat-message-collapser-link-small">${escapeExpression(
        name
      )}</span>`
    );
  }

  @computed("cooked")
  get cookedBodies() {
    const elements = Array.prototype.slice.call(domFromString(this.cooked));

    if (hasLazyVideo(elements)) {
      return this.lazyVideoCooked(elements);
    }

    if (hasImageOnebox(elements)) {
      return this.imageOneboxCooked(elements);
    }

    if (hasImage(elements)) {
      return this.imageCooked(elements);
    }

    if (hasGallery(elements)) {
      return this.galleryCooked(elements);
    }

    return [];
  }

  lazyVideoCooked(elements) {
    return elements.reduce((acc, e) => {
      if (lazyVideoPredicate(e)) {
        const link = escapeExpression(e.dataset.videoUrl || "");
        const title = escapeExpression(e.dataset.videoTitle || "");
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link" rel="noopener noreferrer" href="${link}">${title}</a>`
        );
        const body = document.createElement("div");
        body.className = "chat-message-collapser-lazy-video";
        body.appendChild(e);

        acc.push({ header, body, needsCollapser: true });
      } else {
        acc.push({ body: e, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  imageOneboxCooked(elements) {
    return elements.reduce((acc, e) => {
      if (imageOneboxPredicate(e)) {
        let link = animatedImagePredicate(e)
          ? e.firstChild.src
          : e.firstElementChild.href;

        link = escapeExpression(link);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${link}</a>`
        );
        acc.push({ header, body: e, needsCollapser: true });
      } else {
        acc.push({ body: e, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  imageCooked(elements) {
    return elements.reduce((acc, e) => {
      if (imagePredicate(e)) {
        const link = escapeExpression(e.firstElementChild.src);
        const alt = escapeExpression(e.firstElementChild.alt);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${
            alt || link
          }</a>`
        );
        acc.push({ header, body: e, needsCollapser: true });
      } else {
        acc.push({ body: e, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  galleryCooked(elements) {
    return elements.reduce((acc, e) => {
      if (galleryPredicate(e)) {
        const link = escapeExpression(e.firstElementChild.href);
        const title = escapeExpression(
          e.firstElementChild.firstElementChild.textContent
        );
        e.firstElementChild.removeChild(e.firstElementChild.firstElementChild);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${title}</a>`
        );
        acc.push({ header, body: e, needsCollapser: true });
      } else {
        acc.push({ body: e, needsCollapser: false });
      }
      return acc;
    }, []);
  }
}

function lazyVideoPredicate(e) {
  return e.classList.length && e.classList.contains("lazy-video-container");
}

function hasLazyVideo(elements) {
  return elements.some((e) => lazyVideoPredicate(e));
}

function animatedImagePredicate(e) {
  return (
    e.firstChild &&
    e.firstChild.nodeName === "IMG" &&
    e.firstChild.classList.contains("animated") &&
    e.firstChild.classList.contains("onebox")
  );
}

function externalImageOnebox(e) {
  return (
    e.firstElementChild &&
    e.firstElementChild.nodeName === "A" &&
    e.firstElementChild.classList.contains("onebox") &&
    e.firstElementChild.firstElementChild &&
    e.firstElementChild.firstElementChild.nodeName === "IMG"
  );
}

function imageOneboxPredicate(e) {
  return animatedImagePredicate(e) || externalImageOnebox(e);
}

function hasImageOnebox(elements) {
  return elements.some((e) => imageOneboxPredicate(e));
}

function hasUploads(uploads) {
  return uploads?.length > 0;
}

function imagePredicate(e) {
  return (
    e.nodeName === "P" &&
    e.firstElementChild &&
    e.firstElementChild.nodeName === "IMG" &&
    !e.firstElementChild.classList.contains("emoji")
  );
}

function hasImage(elements) {
  return elements.some((e) => imagePredicate(e));
}

function galleryPredicate(e) {
  return (
    e.firstElementChild &&
    e.firstElementChild.nodeName === "A" &&
    e.firstElementChild.firstElementChild &&
    e.firstElementChild.firstElementChild.classList.contains("outer-box")
  );
}

function hasGallery(elements) {
  return elements.some((e) => galleryPredicate(e));
}

export function isCollapsible(cooked, uploads) {
  const elements = Array.prototype.slice.call(domFromString(cooked));

  return (
    hasLazyVideo(elements) ||
    hasImageOnebox(elements) ||
    hasUploads(uploads) ||
    hasImage(elements) ||
    hasGallery(elements)
  );
}
