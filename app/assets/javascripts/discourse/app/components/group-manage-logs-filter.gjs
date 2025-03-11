{{#if this.value}}
  <DButton
    @action={{fn this.clearFilter this.type}}
    @icon="circle-xmark"
    @translatedLabel={{concat this.label ": " this.filterText}}
    class="btn-default group-manage-logs-filter"
  />
{{/if}}