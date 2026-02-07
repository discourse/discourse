import ColorExample from "discourse/plugins/styleguide/discourse/components/color-example";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const SocialColors = <template>
  <StyleguideExample @title="social brands">
    <section class="color-row">
      <ColorExample @color="google" />
      <ColorExample @color="google-hover" />
      <ColorExample @color="facebook" />
      <ColorExample @color="facebook-hover" />
    </section>
    <section class="color-row">
      <ColorExample @color="github" />
      <ColorExample @color="github-hover" />
      <ColorExample @color="discord" />
      <ColorExample @color="discord-hover" />
    </section>
    <section class="color-row">
      <ColorExample @color="twitter" />
      <ColorExample @color="twitter-hover" />
      <ColorExample @color="instagram" />
      <ColorExample @color="instagram-hover" />
    </section>
  </StyleguideExample>

  <StyleguideExample @title="achievement colors">
    <section class="color-row">
      <ColorExample @color="gold" />
      <ColorExample @color="silver" />
      <ColorExample @color="bronze" />
    </section>
  </StyleguideExample>
</template>;

export default SocialColors;
