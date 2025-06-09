import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/components/d-toggle-switch";

const Toggle = <template>
  <DToggleSwitch @state={{@enabled}} {{on "click" @action}} />
</template>;

export default Toggle;
