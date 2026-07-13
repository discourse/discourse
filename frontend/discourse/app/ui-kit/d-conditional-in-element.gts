import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DConditionalInElementSignature {
  Args: {
    element?: Element | null;
    inline?: boolean;
    append?: boolean;
  };
  Blocks: { default: [] };
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
