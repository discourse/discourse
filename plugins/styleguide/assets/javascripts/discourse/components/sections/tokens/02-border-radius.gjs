import BorderRadiusExample from "discourse/plugins/styleguide/discourse/components/border-radius-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const BorderRadius = <template>
  <StyleguideExample @title="border radius">
    <section class="border-radius-grid">
      <BorderRadiusExample @radius="d-border-radius" />
      <BorderRadiusExample @radius="d-border-radius-large" />
      <BorderRadiusExample @radius="d-nav-pill-border-radius" />
      <BorderRadiusExample @radius="d-input-border-radius" />
      <BorderRadiusExample @radius="d-button-border-radius" />
    </section>
  </StyleguideExample>
</template>;

export default BorderRadius;
