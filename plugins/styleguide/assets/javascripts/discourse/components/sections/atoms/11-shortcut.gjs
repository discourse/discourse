import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import BlockExample from "../../examples/atoms/shortcut/block";
import blockSource from "../../examples/atoms/shortcut/block?source=file";
import KeyboardGateExample from "../../examples/atoms/shortcut/keyboard-gate";
import keyboardGateSource from "../../examples/atoms/shortcut/keyboard-gate?source=file";
import KeycapsExample from "../../examples/atoms/shortcut/keycaps";
import keycapsSource from "../../examples/atoms/shortcut/keycaps?source=file";
import SpellingsExample from "../../examples/atoms/shortcut/spellings";
import spellingsSource from "../../examples/atoms/shortcut/spellings?source=file";
import StringFormExample from "../../examples/atoms/shortcut/string-form";
import stringFormSource from "../../examples/atoms/shortcut/string-form?source=file";

const KEY = "styleguide.sections.shortcut";

export default <template>
  <p class="section-description">
    {{i18n (concat KEY ".description")}}
  </p>

  <StyleguideExample
    @code={{keycapsSource}}
    @description={{i18n (concat KEY ".keycaps_description")}}
    @kind="component"
    @note={{i18n (concat KEY ".keycaps_note")}}
    @title={{i18n (concat KEY ".keycaps_example")}}
  >
    <KeycapsExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{blockSource}}
    @description={{i18n (concat KEY ".block_description")}}
    @kind="component"
    @note={{i18n (concat KEY ".block_note")}}
    @title={{i18n (concat KEY ".block_example")}}
    @tryThis={{i18n (concat KEY ".block_try_this")}}
  >
    <BlockExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{stringFormSource}}
    @description={{i18n (concat KEY ".string_form_description")}}
    @title={{i18n (concat KEY ".string_form_example")}}
    @tryThis={{i18n (concat KEY ".string_form_try_this")}}
  >
    <StringFormExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{spellingsSource}}
    @description={{i18n (concat KEY ".spellings_description")}}
    @note={{i18n (concat KEY ".spellings_note")}}
    @title={{i18n (concat KEY ".spellings_example")}}
  >
    <SpellingsExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{keyboardGateSource}}
    @description={{i18n (concat KEY ".keyboard_gate_description")}}
    @note={{i18n (concat KEY ".keyboard_gate_note")}}
    @title={{i18n (concat KEY ".keyboard_gate_example")}}
    @tryThis={{i18n (concat KEY ".keyboard_gate_try_this")}}
  >
    <KeyboardGateExample />
  </StyleguideExample>
</template>
