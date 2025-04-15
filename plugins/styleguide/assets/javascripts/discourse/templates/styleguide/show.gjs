import RouteTemplate from "ember-route-template";
import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

export default RouteTemplate(
  <template>
    <StyleguideSection @section={{@controller.section}}>
      {{#let @controller.section.component as |SectionComponent|}}
        <SectionComponent
          @dummy={{@controller.dummy}}
          @dummyAction={{@controller.dummyAction}}
          @siteSettings={{@controller.siteSettings}}
        />
      {{/let}}
    </StyleguideSection>
  </template>
);
