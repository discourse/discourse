import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import LargeExample from "../../examples/atoms/thinking/large";
import largeSource from "../../examples/atoms/thinking/large?source=file";
import LavaExample from "../../examples/atoms/thinking/lava";
import lavaSource from "../../examples/atoms/thinking/lava?source=file";
import RibbonsExample from "../../examples/atoms/thinking/ribbons";
import ribbonsSource from "../../examples/atoms/thinking/ribbons?source=file";
import SmallExample from "../../examples/atoms/thinking/small";
import smallSource from "../../examples/atoms/thinking/small?source=file";

export default <template>
  <StyleguideExample @title="DThinking" @code={{largeSource}}>
    <LargeExample />
  </StyleguideExample>

  <StyleguideExample @title='DThinking @size="small"' @code={{smallSource}}>
    <SmallExample />
  </StyleguideExample>

  <StyleguideExample @title='DThinking @type="lava"' @code={{lavaSource}}>
    <LavaExample @size="large" />
  </StyleguideExample>

  <StyleguideExample @title='DThinking @type="lava"' @code={{lavaSource}}>
    <LavaExample @size="small" />
  </StyleguideExample>

  <StyleguideExample @title='DThinking @type="ribbons"' @code={{ribbonsSource}}>
    <RibbonsExample @size="large" />
  </StyleguideExample>

  <StyleguideExample @title='DThinking @type="ribbons"' @code={{ribbonsSource}}>
    <RibbonsExample @size="small" />
  </StyleguideExample>
</template>
