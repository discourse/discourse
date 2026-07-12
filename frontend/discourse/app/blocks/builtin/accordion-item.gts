import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import { i18n } from "discourse-i18n";

interface AccordionItemSignature {
  Args: {
    title?: string;
    defaultOpen?: boolean;
    children?: ChildBlockResult[];
  };
}

/**
 * One collapsible section of an `accordion`: a title that toggles a panel of
 * child blocks. Each item owns its own header and disclosure state, so it
 * needs no coordination from the parent.
 *
 * In an editing context the ambient "edit presentation" capability is set, so
 * the item renders open regardless of `defaultOpen` — the author can see and
 * edit its content in place rather than having to expand it first.
 */
@block("accordion-item", {
  thumbnail: () => import("discourse/blocks/thumbnails/accordion-item"),
  container: true,
  displayName: "Accordion item",
  icon: "chevron-down",
  category: "Layout",
  description: "A collapsible section with a title and content.",
  args: {
    title: {
      type: "string",
      default: "",
      ui: { label: i18n("blocks.builtin.accordion_item.title") },
    },
    defaultOpen: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.accordion_item.default_open"),
      },
    },
  },
})
export default class AccordionItem extends Component<AccordionItemSignature> {
  /**
   * Whether all content should be revealed for editing.
   *
   * @returns Whether an editing context is active.
   */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  /**
   * Whether the section is expanded on initial render.
   *
   * @returns Whether the section starts open.
   */
  get open() {
    // `debugHooks.isEditPresentation` is loosely typed (`unknown`); the
    // disclosure state is genuinely a boolean, so assert it for the `open`
    // attribute. The assertion is erased at runtime.
    return (this.isEditing || (this.args.defaultOpen ?? false)) as boolean;
  }

  <template>
    <details class="d-block-accordion-item" open={{this.open}}>
      <summary class="d-block-accordion-item__summary">{{@title}}</summary>
      <div class="d-block-accordion-item__panel">
        {{#each @children key="key" as |child|}}
          <child.Component />
        {{/each}}
      </div>
    </details>
  </template>
}
