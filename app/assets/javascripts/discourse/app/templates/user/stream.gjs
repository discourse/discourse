{{#if this.model.stream.noContent}}
  <EmptyState
    @title={{this.model.emptyState.title}}
    @body={{this.model.emptyState.body}}
  />
{{/if}}

<UserStream @stream={{this.model.stream}} />