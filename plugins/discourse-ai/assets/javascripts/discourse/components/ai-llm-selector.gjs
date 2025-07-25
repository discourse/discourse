import { hash } from "@ember/helper";
import ComboBox from "select-kit/components/combo-box";

const AiLlmSelector = <template>
  <ComboBox
    @value={{@value}}
    @content={{@llms}}
    @onChange={{@onChange}}
    @options={{hash
      filterable=true
      none="discourse_ai.ai_persona.no_llm_selected"
    }}
    class={{@class}}
  />
</template>;

export default AiLlmSelector;
