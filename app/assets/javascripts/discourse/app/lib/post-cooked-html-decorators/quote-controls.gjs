import { htmlSafe } from "@ember/template";
import curryComponent from "ember-curry-component";
import PostQuotedContent from "discourse/components/post/quoted-content";

export default function quoteControls(element, context) {
  // Extract required properties from context
  const { post, highlightTerm, ignoredUsers, decoratorState, owner, helper } =
    context;

  // Find all quote blocks in the element
  const quotes = element.querySelectorAll("aside.quote");

  if (quotes.length === 0) {
    return;
  }

  // Process each quote block
  quotes.forEach((aside, index) => {
    // Extract quote metadata from HTML dataset
    const {
      post: quotedPostRaw,
      topic: topicRaw,
      username,
      expanded,
      full,
    } = aside.dataset;

    if (!quotedPostRaw) {
      return;
    }

    // Parse quoted post/topic IDs
    const quotedTopicId = parseInt(topicRaw || post.topic_id, 10);
    const quotedPostNumber = parseInt(quotedPostRaw, 10);

    // Extract and sanitize quote title
    const titleEl = aside.querySelector(".title");

    let title;
    if (titleEl) {
      // Remove existing quote controls if present
      titleEl.querySelector(".quote-controls")?.remove();
      title = htmlSafe(titleEl.innerHTML);
    }

    // Get quote content
    const blockquote = aside.querySelector("blockquote");

    // Build props for PostQuotedContent component
    const componentProps = {
      collapsedContent: htmlSafe(blockquote?.innerHTML),
      decoratorState,
      expanded: expanded === "true",
      fullQuote: full === "true",
      highlightTerm,
      id: `quote-id-${quotedTopicId}-${quotedPostNumber}-${index}`,
      ignoredUsers,
      originalText: blockquote?.textContent?.trim(),
      post,
      quotedPostNotFound: aside.classList.contains("quote-post-not-found"),
      quotedPostNumber,
      quotedTopicId,
      title,
      username,
      wrapperElement: aside,
    };

    // Render the PostQuotedContent component in place of original quote
    helper.renderGlimmer(
      aside,
      curryComponent(PostQuotedContent, componentProps, owner),
      null,
      { append: false }
    );
  });
}
