import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CharCounterExample from "../../examples/char-counter";
import charCounterSource from "../../examples/char-counter.gjs?source";

export default <template>
  <StyleguideExample @title="<DCharCounter>" @code={{charCounterSource}}>
    <CharCounterExample @dummy={{@dummy}} />
  </StyleguideExample>
</template>
