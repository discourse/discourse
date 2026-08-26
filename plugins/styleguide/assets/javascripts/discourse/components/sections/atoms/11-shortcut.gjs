import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import BlockExample from "../../examples/atoms/shortcut/block";
import blockSource from "../../examples/atoms/shortcut/block?source=file";
import KeycapsExample from "../../examples/atoms/shortcut/keycaps";
import keycapsSource from "../../examples/atoms/shortcut/keycaps?source=file";

export default <template>
  <StyleguideExample @title="DShortcut @keys" @code={{keycapsSource}}>
    <KeycapsExample />
  </StyleguideExample>

  <StyleguideExample @title="DShortcut as |shortcut|" @code={{blockSource}}>
    <BlockExample />
  </StyleguideExample>
</template>
