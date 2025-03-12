{{#each this._childComponents as |info|}}
  {{#in-element info.element insertBefore=null}}
    <info.component
      @data={{info.data}}
      @setWrapperElementAttrs={{info.setWrapperElementAttrs}}
    />
  {{/in-element}}
{{/each}}