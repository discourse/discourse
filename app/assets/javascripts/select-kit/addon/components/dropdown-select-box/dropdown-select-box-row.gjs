{{#if this.icons}}
  <div class="icons">
    <span class="selection-indicator"></span>
    {{#each this.icons as |icon|}}
      {{d-icon icon}}
    {{/each}}
  </div>
{{/if}}

<div class="texts">
  <span class="name">{{html-safe this.label}}</span>
  {{#if this.description}}
    <span class="desc">{{html-safe this.description}}</span>
  {{/if}}
</div>