{{#if @count}}
  <LinkTo @route="full-page-search" @query={{hash q=this.searchParams}}>
    {{@count}}
  </LinkTo>
{{else}}
  &ndash;
{{/if}}