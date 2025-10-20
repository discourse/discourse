export default function (element, context) {
  restoreOpenedDetails(element, context);
}

function restoreOpenedDetails(element, context) {
  const details = element.querySelectorAll("details");

  details.forEach((detailElement, index) => {
    const id = tagId(detailElement, context, index);
    const state = context.decoratorState;

    if (state.has(id)) {
      detailElement.open = true;
    }

    detailElement.addEventListener("toggle", (event) => {
      if (event.target.open) {
        state.set(id, true);
      } else {
        state.delete(id);
      }
    });
  });
}

export function tagId(
  element,
  context,
  index,
  { topicId, postId, prefix = "" } = {}
) {
  if (element.id) {
    // If the element already has an ID, we don't want to overwrite it.
    return element.id;
  }

  prefix ||= element.tagName.toLowerCase();
  topicId ||= context.post.topic_id || "";
  postId ||= context.post.post_number;

  const id = `post-cooked-html__${prefix}-${topicId}-${postId}-${index}`;
  element.id = id;

  return id;
}
