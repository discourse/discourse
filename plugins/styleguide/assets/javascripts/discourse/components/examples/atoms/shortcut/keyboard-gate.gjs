import Component from "@glimmer/component";
import { service } from "@ember/service";
import DShortcut from "discourse/ui-kit/d-shortcut";

export default class KeyboardGateExample extends Component {
  @service capabilities;

  <template>
    <p>
      <code>capabilities.hasKeyboard</code>
      is currently
      <strong class="styleguide-example__result">
        {{if this.capabilities.hasKeyboard "true" "false"}}
      </strong>
    </p>
    <p>Default: <DShortcut @keys="mod+k" /></p>
    <p>With
      <code>@always</code>:
      <DShortcut @always={{true}} @keys="mod+k" /></p>
  </template>
}
