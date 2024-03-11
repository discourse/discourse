import { createPopper } from "@popperjs/core";
import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";

let inlineFootnotePopper;

function applyInlineFootnotes(elem) {
  const footnoteRefs = elem.querySelectorAll("sup.footnote-ref");

  footnoteRefs.forEach((footnoteRef) => {
    const refLink = footnoteRef.querySelector("a");
    if (!refLink) {
      return;
    }

    const expandableFootnote = document.createElement("a");
    expandableFootnote.classList.add("expand-footnote");
    expandableFootnote.innerHTML = iconHTML("ellipsis-h");
    expandableFootnote.href = "";
    expandableFootnote.role = "button";
    expandableFootnote.dataset.footnoteId = refLink.getAttribute("href");

    footnoteRef.after(expandableFootnote);
  });

  if (footnoteRefs.length) {
    elem.classList.add("inline-footnotes");
  }
}

function buildTooltip() {
  let html = `
    <div id="footnote-tooltip" role="tooltip">
      <div class="footnote-tooltip-content"></div>
      <div id="arrow" data-popper-arrow></div>
    </div>
  `;

  let template = document.createElement("template");
  html = html.trim();
  template.innerHTML = html;
  return template.content.firstChild;
}

function footNoteEventHandler(event) {
  inlineFootnotePopper?.destroy();

  const tooltip = document.getElementById("footnote-tooltip");

  // reset state by hidding tooltip, it handles "click outside"
  // allowing to hide the tooltip when you click anywhere else
  tooltip?.removeAttribute("data-show");

  // if we didn't actually click a footnote button, exit early
  if (!event.target.classList.contains("expand-footnote")) {
    return;
  }

  event.preventDefault();
  event.stopPropagation();

  // append footnote to tooltip body
  const expandableFootnote = event.target;
  const cooked = expandableFootnote.closest(".cooked");
  const footnoteId = expandableFootnote.dataset.footnoteId;
  const footnoteContent = tooltip.querySelector(".footnote-tooltip-content");
  let newContent = cooked.querySelector(footnoteId);

  footnoteContent.innerHTML = newContent.innerHTML;

  // display tooltip
  tooltip.dataset.show = "";

  // setup popper
  inlineFootnotePopper?.destroy();
  inlineFootnotePopper = createPopper(expandableFootnote, tooltip, {
    modifiers: [
      {
        name: "arrow",
        options: { element: tooltip.querySelector("#arrow") },
      },
      {
        name: "preventOverflow",
        options: {
          altAxis: true,
          padding: 5,
        },
      },
      {
        name: "offset",
        options: {
          offset: [0, 12],
        },
      },
    ],
  });
}

export default {
  name: "inline-footnotes",

  initialize(container) {
    if (!container.lookup("service:site-settings").display_footnotes_inline) {
      return;
    }

    document.documentElement.append(buildTooltip());

    window.addEventListener("click", footNoteEventHandler);

    withPluginApi("0.8.9", (api) => {
      api.decorateCookedElement((elem) => applyInlineFootnotes(elem), {
        onlyStream: true,
        id: "inline-footnotes",
      });

      api.onPageChange(() => {
        document
          .getElementById("footnote-tooltip")
          ?.removeAttribute("data-show");
      });
    });
  },

  teardown() {
    inlineFootnotePopper?.destroy();
    window.removeEventListener("click", footNoteEventHandler);
    document.getElementById("footnote-tooltip")?.remove();
  },
};
