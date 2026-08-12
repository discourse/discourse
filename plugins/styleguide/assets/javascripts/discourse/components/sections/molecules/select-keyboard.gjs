import { i18n } from "discourse-i18n";
import KeyboardClearingSelectExample from "../../examples/molecules/select/keyboard/clearing";
import MobileSelectExample from "../../examples/molecules/select/keyboard/mobile";
import OpenBehaviourSelectExample from "../../examples/molecules/select/keyboard/open-behaviour";
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
    @title={{i18n "styleguide.sections.select.open_behaviour_example"}}
    @description={{i18n
      "styleguide.sections.select.open_behaviour_description"
    }}
    @tryThis={{i18n "styleguide.sections.select.open_behaviour_try_this"}}
  >
    <:default>
      <p class="select-examples__pair-label">
        {{i18n "styleguide.sections.select.open_behaviour_empty_label"}}
      </p>
      <div class="select-examples__pair">
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_typeahead"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-empty-typeahead"
            @variant="typeahead"
            @label={{i18n
              "styleguide.sections.select.open_behaviour_typeahead"
            }}
          />
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_button"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-empty-button"
            @variant="button"
            @label={{i18n "styleguide.sections.select.open_behaviour_button"}}
          />
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_static"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-empty-static"
            @variant="static"
            @label={{i18n "styleguide.sections.select.open_behaviour_static"}}
          />
        </div>
      </div>

      <p class="select-examples__pair-label">
        {{i18n "styleguide.sections.select.open_behaviour_filled_label"}}
      </p>
      <div class="select-examples__pair">
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_typeahead"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-filled-typeahead"
            @variant="typeahead"
            @initialValue="fr"
            @label={{i18n
              "styleguide.sections.select.open_behaviour_typeahead"
            }}
          />
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_button"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-filled-button"
            @variant="button"
            @initialValue="fr"
            @label={{i18n "styleguide.sections.select.open_behaviour_button"}}
          />
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.open_behaviour_static"}}
          </p>
          <OpenBehaviourSelectExample
            @identifier="sg-open-filled-static"
            @variant="static"
            @initialValue="fr"
            @label={{i18n "styleguide.sections.select.open_behaviour_static"}}
          />
        </div>
      </div>
    </:default>
    <:note>
      <ul class="styleguide-example__note-list">
        <li>{{i18n "styleguide.sections.select.open_behaviour_note_empty"}}</li>
        <li>{{i18n
            "styleguide.sections.select.open_behaviour_note_filled"
          }}</li>
        <li>{{i18n "styleguide.sections.select.open_behaviour_note_rule"}}</li>
      </ul>
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
