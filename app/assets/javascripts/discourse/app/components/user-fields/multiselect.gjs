<label
  class="control-label alt-placeholder"
  for={{concat "user-" this.elementId}}
>
  {{this.field.name}}
  {{~#unless this.field.required}} {{i18n "user_fields.optional"}}{{/unless~}}
</label>

<div class="controls">
  <MultiSelect
    @id={{concat "user-" this.elementId}}
    @content={{this.field.options}}
    @valueProperty={{null}}
    @nameProperty={{null}}
    @value={{this.value}}
    @onChange={{fn (mut this.value)}}
    @options={{hash none=this.noneLabel}}
  />
  <div class="instructions">{{html-safe this.field.description}}</div>
</div>