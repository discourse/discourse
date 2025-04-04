import DToggleSwitch from "discourse/components/d-toggle-switch";
import { on } from "@ember/modifier";
const Toggle = <template><DToggleSwitch @state={{@enabled}} {{on "click" @action}} /></template>;
export default Toggle;