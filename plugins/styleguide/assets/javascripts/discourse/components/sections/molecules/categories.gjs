<StyleguideExample @title="category-badge - bullet">
  {{#each @dummy.categories as |c|}}
    {{category-badge c categoryStyle="bullet"}}
  {{/each}}
</StyleguideExample>

<StyleguideExample @title="category-badge - bar">
  {{#each @dummy.categories as |c|}}
    {{category-badge c categoryStyle="bar"}}
  {{/each}}
</StyleguideExample>

<StyleguideExample @title="category-badge - box">
  {{#each @dummy.categories as |c|}}
    {{category-badge c categoryStyle="box"}}
  {{/each}}
</StyleguideExample>

<StyleguideExample @title="category-badge - none">
  {{#each @dummy.categories as |c|}}
    {{category-badge c categoryStyle="none"}}
  {{/each}}
</StyleguideExample>