import ValidationMessages from "form-kit/components/validation-messages";

const Meta = <template>
  <div class="d-form-field__meta">
    {{#if @node.valid}}
      {{#if @node.props.help}}
        <p class="d-form-field__meta-text">{{@node.props.help}}</p>
      {{/if}}
    {{else}}
      <ValidationMessages @node={{@node}} />
    {{/if}}
  </div>
</template>;

export default Meta;
