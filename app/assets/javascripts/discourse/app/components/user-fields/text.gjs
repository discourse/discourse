<div class="controls">
  <Input
    id={{concat "user-" this.elementId}}
    @value={{this.value}}
    maxlength={{this.site.user_field_max_length}}
  />
  <label
    class="control-label alt-placeholder"
    for={{concat "user-" this.elementId}}
  >
    {{this.field.name}}
    {{~#unless this.field.required}} {{i18n "user_fields.optional"}}{{/unless~}}
  </label>
  <InputTip
    @validation={{this.validation}}
    class={{unless this.validation "hidden"}}
  />
  {{#unless this.validation}}
    <div class="instructions">{{html-safe this.field.description}}</div>
  {{/unless}}
</div>