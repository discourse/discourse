import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DConditionalInElementSignature {
  Args: {
    /** The element to render the content into, when not inline. */
    element?: Element | null;

    /** Whether to render in place instead of into `@element`. */
    inline?: boolean;

    /** Whether to append to `@element` rather than replace its content. */
    append?: boolean;
  };
  Blocks: {
    /** The content to render into the target. */
    default: [];
  };
}

const DConditionalInElement: TemplateOnlyComponent<DConditionalInElementSignature> =
  <template>
    {{#if @inline}}
      {{yield}}
    {{else if @element}}
      {{#if @append}}
        {{#in-element @element insertBefore=null}}{{yield}}{{/in-element}}
      {{else}}
        {{#in-element @element}}{{yield}}{{/in-element}}
      {{/if}}
    {{/if}}
  </template>;

export default DConditionalInElement;
