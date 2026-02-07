import ShadowExample from "discourse/plugins/styleguide/discourse/components/shadow-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const Shadows = <template>
  <StyleguideExample @title="shadows">
    <section class="shadow-grid">
      <ShadowExample @shadow="shadow-modal" />
      <ShadowExample @shadow="shadow-composer" />
      <ShadowExample @shadow="shadow-card" />
      <ShadowExample @shadow="shadow-dropdown" />
      <ShadowExample @shadow="shadow-menu-panel" />
      <ShadowExample @shadow="shadow-header" />
      <ShadowExample @shadow="shadow-footer-nav" />
      <ShadowExample @shadow="shadow-focus-danger" />
    </section>
  </StyleguideExample>
</template>;

export default Shadows;
