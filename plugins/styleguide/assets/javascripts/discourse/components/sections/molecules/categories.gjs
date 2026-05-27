import Component from "@glimmer/component";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Categories extends Component {
  categoryBadgeCode = `{{#each @dummy.categories as |c|}}
  {{categoryBadge c categoryStyle="bullet"}}
{{/each}}`;

  <template>
    <StyleguideExample @title="categoryBadge" @code={{this.categoryBadgeCode}}>
      {{#each @dummy.categories as |c|}}
        {{dCategoryBadge c categoryStyle="bullet"}}
      {{/each}}
    </StyleguideExample>
  </template>
}
