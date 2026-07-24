// Swaps the title and preview of internal topic onebox cards with the reader's
// language when the post is shown in its original form (see PostSerializer
// #localized_oneboxes). Same-topic inline quotes carry a data-username and are
// left untouched. Runs before quote-controls so the rendered quote component
// picks up the already-localized text.
//
// title and excerpt are server-rendered, sanitized HTML (HTML-escaped text with
// emoji <img> tags), matching the baked onebox card, so both are assigned via
// innerHTML — textContent would show emoji markup as literal text.
export default function decorateLocalizedOneboxes(element, context) {
  const { post } = context;

  const localized = post.localized_oneboxes;
  if (!localized?.length) {
    return;
  }

  for (const { topic_id, post_number, title, excerpt } of localized) {
    const selector = `aside.quote[data-topic="${topic_id}"][data-post="${post_number}"]:not([data-username])`;

    element.querySelectorAll(selector).forEach((aside) => {
      if (title) {
        // the title link, not the category badge that also lives in .title
        const titleLink =
          aside.querySelector(".quote-title__text-content a[href]") ??
          aside.querySelector(".title a[href]");
        if (titleLink) {
          titleLink.innerHTML = title;
        }
      }

      if (excerpt) {
        const blockquote = aside.querySelector("blockquote");
        if (blockquote) {
          blockquote.innerHTML = excerpt;
        }
      }
    });
  }
}
