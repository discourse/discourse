<a
  href={{this.hrefLink}}
  class={{this.activeClass}}
  aria-current={{if this.activeClass "page"}}
>
  {{#if this.hasIcon}}
    <span class={{this.content.name}}></span>
  {{/if}}
  {{this.content.displayName}}
</a>