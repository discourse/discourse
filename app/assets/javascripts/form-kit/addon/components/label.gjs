const FkLabel = <template>
  <label for={{@fieldId}} ...attributes>
    {{yield}}

    {{#if @optional}}
      <span class="form-kit-field__optional">(Optional)</span>
    {{/if}}
  </label>
</template>;

export default FkLabel;
