const FkLabel = <template>
  <label for={{@fieldId}} ...attributes>
    {{yield}}

    {{#if @optional}}
      <span class="d-form-field__optional">(Optional)</span>
    {{/if}}
  </label>
</template>;

export default FkLabel;
