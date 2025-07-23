import { hash } from "@ember/helper";
import MultiSelect from "select-kit/components/multi-select";

const AiToolSelector = <template>
  <MultiSelect
    @value={{@value}}
    @onChange={{@onChange}}
    @content={{@content}}
    @options={{hash filterable=true allowAny=false disabled=@disabled}}
  />
</template>;

export default AiToolSelector;
