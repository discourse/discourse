import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

export default <template>
  {{! The section and group args go to the SECTION COMPONENT only, never to StyleguideSection.
  That component takes exactly one arg today; adding a second invalidates its args tag, which
  re-fires didReceiveAttrs and its scroll-to-top on every group change — the jump the
  query-param approach exists to avoid. Sections that ignore these args are unaffected. }}
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
