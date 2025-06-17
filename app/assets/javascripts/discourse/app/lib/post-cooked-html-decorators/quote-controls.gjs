import { htmlSafe } from "@ember/template";
import curryComponent from "ember-curry-component";
import PostQuotedContent from "discourse/components/post/quoted-content";

// TODO (glimmer-post-stream): investigate whether all this complex logic can be replaced with a proper Glimmer component
export default function (element, context) {
  const { data, cloakedState, owner } = context;

  const quotes = element.querySelectorAll("aside.quote");
  if (quotes.length === 0) {
    return;
  }

  quotes.forEach((aside, index) => {
    if (aside.dataset.post) {
      const quotedTopicId = parseInt(
        aside.dataset.topic || data.post.topic_id,
        10
      );
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

      const collapsedContent = htmlSafe(
        aside.querySelector("blockquote")?.innerHTML
      );

      context.helper.renderGlimmer(
        aside,
        curryComponent(
          PostQuotedContent,
          {
            id: quoteId,
            highlightTerm: data.highlightTerm,
            collapsedContent,
            title,
            fullQuote: aside.dataset.full === "true",
            expanded: aside.dataset.expanded === "true",
            ignoredUsers: data.ignoredUsers,
            post: data.post,
            quotedPostNotFound,
            quotedTopicId,
            quotedPostNumber,
            cloakedState,
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
