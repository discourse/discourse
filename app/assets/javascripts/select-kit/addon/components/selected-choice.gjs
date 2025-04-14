{{#if this.readOnly}}
  <button
    class="btn btn-default disabled"
    title={{I18n "admin.site_settings.mandatory_group"}}
  >{{this.itemName}}</button>
{{else}}
  <button
    {{on "click" (fn this.selectKit.deselect this.item)}}
    aria-label={{i18n "select_kit.delete_item" name=this.itemName}}
    data-value={{this.itemValue}}
    data-name={{this.itemName}}
    type="button"
    id="{{this.id}}-choice"
    class="btn btn-default selected-choice {{this.extraClass}}"
  >
    {{d-icon "xmark"}}
    {{#if (has-block)}}
      {{yield}}
    {{else}}
      <span class="d-button-label">
        {{this.itemName}}
      </span>
    {{/if}}
  </button>
{{/if}}