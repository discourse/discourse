import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

export default <template>
  {{! The group arg goes to the SECTION COMPONENT only, never to StyleguideSection. That wrapper
  takes exactly one arg today; adding a second invalidates its args tag, so every group change
  would re-fire its didReceiveAttrs hook and re-run the whole section wrapper's setup rather than
  only swapping the group's body. Sections that ignore these args are unaffected. }}
  <StyleguideSection @section={{@controller.section}}>
    {{#let @controller.section.component as |SectionComponent|}}
      <SectionComponent
        @dummy={{@controller.dummy}}
        @dummyAction={{@controller.dummyAction}}
        @siteSettings={{@controller.siteSettings}}
        @section={{@controller.section}}
        @group={{@controller.group}}
      />
    {{/let}}
  </StyleguideSection>
</template>
