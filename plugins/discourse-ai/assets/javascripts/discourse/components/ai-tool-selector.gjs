import { hash } from "@ember/helper";
import MultiSelect from "discourse/select-kit/components/multi-select";

const AiToolSelector = <template>
  <MultiSelect
    @content={{@content}}
    @onChange={{@onChange}}
    @options={{hash filterable=true allowAny=false disabled=@disabled}}
    @value={{@value}}
  />
</template>;

export default AiToolSelector;
