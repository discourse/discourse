import { htmlSafe } from "@ember/template";
import curryComponent from "ember-curry-component";
import PostQuotedContent from "discourse/components/post/quoted-content";

export default function quoteControls(element, context) {
  const { post, highlightTerm, ignoredUsers, decoratorState, owner } = context;

  const quotes = element.querySelectorAll("aside.quote");
  if (quotes.length === 0) {
    return;
  }

  quotes.forEach((aside, index) => {
    if (aside.dataset.post) {
      const quotedTopicId = parseInt(aside.dataset.topic || post.topic_id, 10);
      const quotedPostNumber = parseInt(aside.dataset.post, 10);

      const quoteId = `quote-id-${quotedTopicId}-${quotedPostNumber}-${index}`;

      const quotedPostNotFound = aside.classList.contains(
        "quote-post-not-found"
      );
      const username = aside.dataset.username;

      let title = aside.querySelector(".title");

      // extract the title HTML without the quote controls DIV
      if (title) {
        title.querySelector(".quote-controls").remove();
        title = htmlSafe(title.innerHTML);
      }

      const originalText = aside
        .querySelector("blockquote")
        ?.textContent?.trim();

      const collapsedContent = htmlSafe(
        aside.querySelector("blockquote")?.innerHTML
      );

      context.helper.renderGlimmer(
        aside,
        curryComponent(
          PostQuotedContent,
          {
            decoratorState,
            collapsedContent,
            expanded: aside.dataset.expanded === "true",
            fullQuote: aside.dataset.full === "true",
            highlightTerm,
            id: quoteId,
            ignoredUsers,
            originalText,
            post,
            quotedPostNotFound,
            quotedPostNumber,
            quotedTopicId,
            title,
            username,
            wrapperElement: aside,
          },
          owner
        ),
        null,
        { append: false }
      );
    }
  });
}
