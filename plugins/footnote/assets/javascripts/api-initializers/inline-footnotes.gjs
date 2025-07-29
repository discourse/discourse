import { htmlSafe } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";

const TooltipContentComponent = <template>
  {{htmlSafe @data.contentHtml}}
</template>;

export default apiInitializer((api) => {
  function onFootnoteClick(event) {
    event.preventDefault();

    const tooltipService = api.container.lookup("service:tooltip");

    const instance = new DTooltipInstance(api.container, {
      identifier: "inline-footnote",
      interactive: true,
      closeOnScroll: false,
      closeOnClickOutside: true,
      component: TooltipContentComponent,
      data: {
        contentHtml: event.target.dataset.footnoteContent,
      },
    });
    instance.trigger = event.target;
    instance.detachedTrigger = true;

    tooltipService.show(instance);
  }

  api.decorateCookedElement((elem) => {
    if (
      !api.container.lookup("service:site-settings").display_footnotes_inline
    ) {
      return;
    }

    const footnoteRefs = elem.querySelectorAll("sup.footnote-ref");

    footnoteRefs.forEach((footnoteRef) => {
      const refLink = footnoteRef.querySelector("a");
      if (!refLink) {
        return;
      }

      const footnoteId = refLink.getAttribute("href");
      const footnoteContent = elem.querySelector(footnoteId)?.innerHTML;

      const expandableFootnote = document.createElement("a");
      expandableFootnote.classList.add("expand-footnote");
      expandableFootnote.href = "";
      expandableFootnote.role = "button";
      expandableFootnote.dataset.footnoteId = footnoteId;
      expandableFootnote.dataset.footnoteContent = footnoteContent;
      expandableFootnote.addEventListener("click", onFootnoteClick);

      footnoteRef.after(expandableFootnote);
    });

    if (footnoteRefs.length) {
      elem.classList.add("inline-footnotes");
    }
  });
});
