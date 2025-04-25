<div class="select-kit-header-wrapper">
  {{#each this.icons as |icon|}} {{d-icon icon}} {{/each}}

  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
  }}

  {{#if this.shouldDisplayClearableButton}}
    <DButton
      @icon="xmark"
      @action={{this.selectKit.onClearSelection}}
      @ariaLabel="clear_input"
      class="btn-clear"
    />
  {{/if}}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>