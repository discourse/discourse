import { i18n } from "discourse-i18n";
import KeyboardClearingSelectExample from "../../examples/molecules/select/keyboard/clearing";
import MobileSelectExample from "../../examples/molecules/select/keyboard/mobile";
import KeyboardTranscriptSelectExample from "../../examples/molecules/select/keyboard/transcript";
import KeyboardWalkthroughSelectExample from "../../examples/molecules/select/keyboard/walkthrough";
import StyleguideExample from "../../styleguide-example";

export default <template>
  <StyleguideExample
    class="--wide"
    @title={{i18n "styleguide.sections.select.keyboard_walkthrough_example"}}
    @description={{i18n
      "styleguide.sections.select.keyboard_walkthrough_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.keyboard_walkthrough_try_this"}}
  >
    <:default>
      <div class="select-examples__control">
        <KeyboardWalkthroughSelectExample />
      </div>
    </:default>
    <:note>
      <ol class="styleguide-example__note-list" data-test-keyboard-steps>
        <li>{{i18n "styleguide.sections.select.keyboard_step_open"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_move"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_page"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_home_end"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_choose"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_escape"}}</li>
        <li>{{i18n "styleguide.sections.select.keyboard_step_tab"}}</li>
      </ol>
    </:note>
  </StyleguideExample>

  <StyleguideExample
    class="--wide"
    @title={{i18n "styleguide.sections.select.keyboard_transcript_example"}}
    @description={{i18n
      "styleguide.sections.select.keyboard_transcript_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.keyboard_transcript_try_this"}}
  >
    <div class="select-examples__control">
      <KeyboardTranscriptSelectExample />
    </div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.keyboard_clearing_example"}}
    @description={{i18n
      "styleguide.sections.select.keyboard_clearing_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.keyboard_clearing_try_this"}}
  >
    <div class="select-examples__control">
      <KeyboardClearingSelectExample />
    </div>
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.select.keyboard_mobile_example"}}
    @description={{i18n
      "styleguide.sections.select.keyboard_mobile_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.keyboard_mobile_try_this"}}
  >
    <:default>
      <div class="select-examples__control"><MobileSelectExample /></div>
    </:default>
    <:note>
      <ul class="styleguide-example__note-list">
        <li>{{i18n
            "styleguide.sections.select.keyboard_mobile_note_input"
          }}</li>
        <li>{{i18n
            "styleguide.sections.select.keyboard_mobile_note_static"
          }}</li>
        <li>{{i18n
            "styleguide.sections.select.keyboard_mobile_note_chips"
          }}</li>
      </ul>
    </:note>
  </StyleguideExample>
</template>
