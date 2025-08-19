import BreadCrumbs from "discourse/components/bread-crumbs";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const BreadCrumbsMolecule = <template>
  <StyleguideExample @title="category-breadcrumbs">
    <BreadCrumbs @categories={{@dummy.categories}} @showTags={{false}} />
  </StyleguideExample>

  {{#if @siteSettings.tagging_enabled}}
    <StyleguideExample @title="category-breadcrumbs - tags">
      <BreadCrumbs @categories={{@dummy.categories}} @showTags={{true}} />
    </StyleguideExample>
  {{/if}}
</template>;

export default BreadCrumbsMolecule;
