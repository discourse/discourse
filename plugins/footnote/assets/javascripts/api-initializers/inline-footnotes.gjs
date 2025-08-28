import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";
import DTooltip from "float-kit/components/d-tooltip";

class InlineFootnote extends Component {
  @action
  preventDefault(event) {
    event.preventDefault();
  }

  <template>
    <DTooltip
      @identifier="inline-footnote"
      @interactive={{true}}
      @closeOnScroll={{false}}
      @closeOnClickOutside={{true}}
    >
      <:trigger>
        {{! template-lint-disable no-invalid-link-text }}
        <a
          class="expand-footnote"
          href
          role="button"
          data-footnote-id={{@data.footnoteId}}
          data-footnote-content={{@data.footnoteContent}}
          {{on "click" this.preventDefault}}
        ></a>
      </:trigger>
      <:content>
        {{htmlSafe @data.footnoteContent}}
      </:content>
    </DTooltip>
  </template>
}

export default apiInitializer((api) => {
  api.decorateCookedElement((elem, helper) => {
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

      const expandableFootnote = document.createElement("span");
      expandableFootnote.className = "inline-footnote";
      footnoteRef.replaceWith(expandableFootnote);

      helper.renderGlimmer(expandableFootnote, InlineFootnote, {
        footnoteId,
        footnoteContent,
      });
    });

    if (footnoteRefs.length) {
      elem.classList.add("inline-footnotes");
    }
  });
});
