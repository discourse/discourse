{{#if this.isTag}}
  {{discourse-tag
    this.rowValue
    noHref=true
    description=this.item.description
    count=this.item.count
  }}
{{else}}
  <span class="name">{{this.item.name}}</span>
{{/if}}