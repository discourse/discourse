import { renderIcon } from "discourse/lib/icon-library";

export default function decorateAiThinking(element) {
  element
    .querySelectorAll("details.ai-thinking > summary")
    .forEach((summary) => {
      summary.parentElement.classList.add("ai-details");
      summary.classList.add("ai-details__summary");

      if (summary.querySelector(":scope > .ai-details__caret")) {
        return;
      }

      summary.prepend(
        renderIcon("element", "chevron-right", {
          class: "ai-details__caret --collapsed",
        }),
        renderIcon("element", "chevron-down", {
          class: "ai-details__caret --expanded",
        })
      );
    });
}
