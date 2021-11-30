import renderTag from "discourse/lib/render-tag";

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

export default function (topic, params) {
  let tags = topic.tags;
  let buffer = "";
  let tagsForUser = null;
  let tagName;
  const isPrivateMessage = topic.get("isPrivateMessage");

  if (params) {
    if (params.mode === "list") {
      tags = topic.get("visibleListTags");
    }
    if (params.tagsForUser) {
      tagsForUser = params.tagsForUser;
    }
    if (params.tagName) {
      tagName = params.tagName;
    }
  }

  let customHtml = null;
  if (callbacks) {
    callbacks.forEach((c) => {
      const html = c(topic, params);
      if (html) {
        if (customHtml) {
          customHtml += html;
        } else {
          customHtml = html;
        }
      }
    });
  }

  if (customHtml || (tags && tags.length > 0)) {
    buffer = "<div class='discourse-tags'>";
    if (tags) {
      for (let i = 0; i < tags.length; i++) {
        buffer +=
          renderTag(tags[i], {
            description:
              topic.tags_descriptions && topic.tags_descriptions[tags[i]],
            isPrivateMessage,
            tagsForUser,
            tagName,
          }) + " ";
      }
    }

    if (customHtml) {
      buffer += customHtml;
    }

    buffer += "</div>";
  }
  return buffer;
}
