import SpacingExample from "discourse/plugins/styleguide/discourse/components/spacing-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const Spacing = <template>
  <StyleguideExample @title="base spacing">
    <section class="spacing-row">
      <SpacingExample @spacing="space" />
      <SpacingExample @spacing="space-half" />
    </section>
  </StyleguideExample>

  <StyleguideExample @title="spacing scale">
    <section class="spacing-row">
      <SpacingExample @spacing="space-1" />
      <SpacingExample @spacing="space-2" />
      <SpacingExample @spacing="space-3" />
      <SpacingExample @spacing="space-4" />
    </section>
    <section class="spacing-row">
      <SpacingExample @spacing="space-5" />
      <SpacingExample @spacing="space-6" />
      <SpacingExample @spacing="space-7" />
      <SpacingExample @spacing="space-8" />
    </section>
    <section class="spacing-row">
      <SpacingExample @spacing="space-9" />
      <SpacingExample @spacing="space-10" />
      <SpacingExample @spacing="space-11" />
      <SpacingExample @spacing="space-12" />
    </section>
  </StyleguideExample>
</template>;

export default Spacing;
