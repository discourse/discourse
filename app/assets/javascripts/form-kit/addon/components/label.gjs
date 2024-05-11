const Label = <template>
  <label class="d-form__col --col-4 d-form-field__label" for={{@for}}>
    {{@label}}
    {{#if @optional}}
      <span class="d-form-field__optional">(Optional)</span>
    {{/if}}
  </label>
</template>;

export default Label;
