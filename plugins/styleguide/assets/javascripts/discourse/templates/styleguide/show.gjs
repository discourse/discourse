import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

export default <template>
  <StyleguideSection @section={{@controller.section}}>
    {{#let @controller.section.component as |SectionComponent|}}
      <SectionComponent
        @dummy={{@controller.dummy}}
        @dummyAction={{@controller.dummyAction}}
        @createTopic={{@controller.createTopic}}
        @replyToPost={{@controller.replyToPost}}
        @siteSettings={{@controller.siteSettings}}
      />
    {{/let}}
  </StyleguideSection>
</template>
