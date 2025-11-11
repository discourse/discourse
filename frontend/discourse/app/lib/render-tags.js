import renderTag from "discourse/lib/render-tag";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

let callbacks = null;
let priorities = null;

export function addTagsHtmlCallback(callback, options) {
  callbacks = callbacks || [];
  priorities = priorities || [];
  const priority = (options && options.priority) || 0;

  let i = 0;
  while (i < priorities.length && priorities[i] > priority) {
    i += 1;
  }

  priorities.splice(i, 0, priority);
  callbacks.splice(i, 0, callback);
}

export function clearTagsHtmlCallbacks() {
  callbacks = null;
  priorities = null;
}

export default function (topic, params) {
  let tags = topic?.tags || params?.tags;
  let buffer = "";
  let tagsForUser = null;
  let tagName;

  const isPrivateMessage = topic?.get("isPrivateMessage");

  if (params) {
    if (params.mode === "list") {
      tags = topic?.get("visibleListTags");
    }
    if (params.tagsForUser) {
      tagsForUser = params.tagsForUser;
    }
    if (params.tagName) {
      tagName = params.tagName;
    }
  }

  const separator = (index) => {
    return applyValueTransformer("tag-separator", ",", {
      topic,
      index,
    });
  };

  const separatorSpan = (index) => {
    return `<span class="discourse-tags__tag-separator">${separator(
      index
    )}</span>`;
  };

  const callbackResults = [];

  if (callbacks && topic) {
    callbacks.forEach((c) => {
      const html = c(topic, params);
      if (html) {
        callbackResults.push(html);
      }
    });
  }

  const hasContent = (tags && tags.length > 0) || callbackResults.length > 0;

  if (hasContent) {
    buffer = `<div class='discourse-tags' 
                   role='list' 
                   aria-label=${i18n("tagging.tags")}>`;

    let currentIndex = 0;

    if (tags && tags.length > 0) {
      for (let i = 0; i < tags.length; i++) {
        const tag = tags[i];
        const tagParams = params ? { ...params } : {};

        if (params?.tagClasses && params?.tagClasses[tag]) {
          tagParams.extraClass = params.tagClasses[tag];
        }

        buffer += renderTag(tag, {
          description: topic?.tags_descriptions?.[tag],
          isPrivateMessage,
          tagsForUser,
          tagName,
          ...tagParams,
        });

        // separator after each tag
        // except if it's the last tag
        // and there are no customizations
        if (i < tags.length - 1 || callbackResults.length > 0) {
          buffer += separatorSpan(currentIndex);
          currentIndex++;
        }
      }
    }

    // add custom results with separator
    for (let i = 0; i < callbackResults.length; i++) {
      buffer += callbackResults[i];

      // don't add separator to the last item
      if (i < callbackResults.length - 1) {
        buffer += separatorSpan(currentIndex);
        currentIndex++;
      }
    }

    buffer += "</div>";
  }

  return buffer;
}
