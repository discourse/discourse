import categoryBadge from "discourse/helpers/category-badge";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const Categories = <template>
  <StyleguideExample @title="category-badge - bullet">
    {{#each @dummy.categories as |c|}}
      {{categoryBadge c categoryStyle="bullet"}}
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title="category-badge - bar">
    {{#each @dummy.categories as |c|}}
      {{categoryBadge c categoryStyle="bar"}}
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title="category-badge - box">
    {{#each @dummy.categories as |c|}}
      {{categoryBadge c categoryStyle="box"}}
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title="category-badge - none">
    {{#each @dummy.categories as |c|}}
      {{categoryBadge c categoryStyle="none"}}
    {{/each}}
  </StyleguideExample>
</template>;

export default Categories;
