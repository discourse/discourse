import { schedule } from "@ember/runloop";
import { reveal } from "discourse/lib/highlight-html";
import { highlightQuote, QUOTE_HIGHLIGHT_ID } from "discourse/lib/quote";

export default function (element, { quoteHighlight }) {
  if (!quoteHighlight) {
    return;
  }

  schedule("afterRender", () => {
    const highlights = highlightQuote(element, quoteHighlight.quote);
    const anchor = highlights[0] ?? element.closest(".topic-post") ?? element;
    anchor.id = QUOTE_HIGHLIGHT_ID;

    if (!quoteHighlight.revealed) {
      quoteHighlight.revealed = true;
      reveal(highlights);
    }
  });
}
