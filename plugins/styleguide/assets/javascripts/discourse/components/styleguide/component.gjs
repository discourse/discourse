import { or } from "truth-helpers";

const Component = <template>
  <div class="styleguide__component">
    {{#if @tag}}
      <span class="styleguide__component-tag">{{@tag}}</span>
    {{/if}}

    {{#if (has-block "title")}}
      <div class="styleguide__component-title">
        {{yield to="title"}}
      </div>
    {{/if}}

    {{#if (or (has-block) (has-block "sample"))}}
      <div class="styleguide__component-sample">
        {{#if (has-block)}}
          {{yield}}
        {{/if}}

        {{#if (has-block "sample")}}
          {{yield to="sample"}}
        {{/if}}
      </div>
    {{/if}}

    {{#if (has-block "actions")}}
      <div class="styleguide__component-actions">
        {{yield to="actions"}}
      </div>
    {{/if}}

    {{#if (has-block "code")}}
      <div class="styleguide__component-code">
        {{yield to="code"}}
      </div>
    {{/if}}
  </div>
</template>;

export default Component;
