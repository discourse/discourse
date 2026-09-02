import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CharCounterExample from "../../examples/molecules/char-counter";
import charCounterSource from "../../examples/molecules/char-counter?source=file";

export default <template>
  <StyleguideExample @code={{charCounterSource}} @title="<DCharCounter>">
    <CharCounterExample />
  </StyleguideExample>
</template>
