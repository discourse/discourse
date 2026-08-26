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
    @title={{i18n (concat KEY ".keycaps_example")}}
    @description={{i18n (concat KEY ".keycaps_description")}}
    @note={{i18n (concat KEY ".keycaps_note")}}
    @kind="component"
    @code={{keycapsSource}}
  >
    <KeycapsExample />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n (concat KEY ".block_example")}}
    @description={{i18n (concat KEY ".block_description")}}
    @tryThis={{i18n (concat KEY ".block_try_this")}}
    @note={{i18n (concat KEY ".block_note")}}
    @kind="component"
    @code={{blockSource}}
  >
    <BlockExample />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n (concat KEY ".string_form_example")}}
    @description={{i18n (concat KEY ".string_form_description")}}
    @tryThis={{i18n (concat KEY ".string_form_try_this")}}
    @code={{stringFormSource}}
  >
    <StringFormExample />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n (concat KEY ".spellings_example")}}
    @description={{i18n (concat KEY ".spellings_description")}}
    @note={{i18n (concat KEY ".spellings_note")}}
    @code={{spellingsSource}}
  >
    <SpellingsExample />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n (concat KEY ".keyboard_gate_example")}}
    @description={{i18n (concat KEY ".keyboard_gate_description")}}
    @tryThis={{i18n (concat KEY ".keyboard_gate_try_this")}}
    @note={{i18n (concat KEY ".keyboard_gate_note")}}
    @code={{keyboardGateSource}}
  >
    <KeyboardGateExample />
  </StyleguideExample>
</template>
