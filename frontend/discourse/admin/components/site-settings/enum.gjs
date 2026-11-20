import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";

const Enum = <template>
  <div ...attributes>
    <ComboBox
      @content={{@setting.validValues}}
      @nameProperty={{@setting.computedNameProperty}}
      @onChange={{@changeValueCallback}}
      @options={{hash
        castInteger=true
        allowAny=@setting.allowsNone
        disabled=@disabled
      }}
      @value={{@value}}
      @valueProperty={{@setting.computedValueProperty}}
    />

    {{@preview}}
  </div>
</template>;

export default Enum;
