import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../lib/select-fixtures";
import StyleguideExample from "../../styleguide-example";

const MAX_ENTRIES = 6;

/**
 * The accessibility group: what the control does for a reader who never touches a mouse.
 *
 * Nothing on this page surfaced an announcement before, even though richer screen-reader
 * feedback is one of the component's headline claims — so the transcript below is the group's
 * centrepiece rather than the walkthrough.
 */
export default class SelectKeyboard extends Component {
  @service a11y;

  @tracked entries = [];
  @tracked transcriptValue = [];
  @tracked walkthroughValue = null;
  @tracked clearableValue = "fr";
  @tracked mobileValue = null;

  locales = LOCALES;

  /**
   * Mirrors the shared live region into a visible list.
   *
   * Deliberately NOT a live region itself — no `role="log"`, no `aria-live`, and hidden from
   * assistive technology — because a page demonstrating announcements must not cause every one
   * of them to be spoken twice.
   *
   * Two honest caveats it cannot hide: the region is global, so anything else announcing lands
   * here too; and messages are coalesced per runloop, so this shows flushes rather than calls.
   */
  @action
  captureAnnouncement() {
    const message = this.a11y.politeMessage;

    // The service writes an empty string to clear itself; those are not announcements.
    if (!message) {
      return;
    }

    this.entries = [message, ...this.entries].slice(0, MAX_ENTRIES);
  }

  @action
  updateClearable(value) {
    this.clearableValue = value;
  }

  @action
  updateMobile(value) {
    this.mobileValue = value;
  }

  @action
  updateTranscript(value) {
    this.transcriptValue = value;
  }

  @action
  updateWalkthrough(value) {
    this.walkthroughValue = value;
  }

  <template>
    <StyleguideExample
      class="--wide"
      @title={{i18n "styleguide.sections.select.keyboard_walkthrough_example"}}
      @description={{i18n
        "styleguide.sections.select.keyboard_walkthrough_description"
      }}
      @tryThis={{i18n
        "styleguide.sections.select.keyboard_walkthrough_try_this"
      }}
    >
      <:default>
        <div class="select-examples__control">
          <DSelect
            @identifier="sg-keyboard-walkthrough"
            @items={{this.locales}}
            @placement="top-start"
            @value={{this.walkthroughValue}}
            @onChange={{this.updateWalkthrough}}
            @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          />
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
      @tryThis={{i18n
        "styleguide.sections.select.keyboard_transcript_try_this"
      }}
    >
      <div class="select-examples__control">
        {{! Multi-select on purpose: add/remove are announced, whereas a single-select
        selection is conveyed by aria-selected alone and would leave the log looking dead. }}
        <DSelect
          @identifier="sg-keyboard-transcript"
          @items={{this.locales}}
          @placement="top-start"
          @multiple={{true}}
          @value={{this.transcriptValue}}
          @onChange={{this.updateTranscript}}
          @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
        />
      </div>

      <div
        class="select-keyboard__transcript"
        aria-hidden="true"
        data-test-announcement-log
        {{didUpdate this.captureAnnouncement this.a11y.politeMessage}}
      >
        <p class="select-keyboard__transcript-title">
          {{i18n "styleguide.sections.select.keyboard_transcript_title"}}
        </p>

        {{#if this.entries}}
          <ul class="select-keyboard__transcript-list">
            {{#each this.entries key="@index" as |entry|}}
              <li class="select-keyboard__transcript-entry">{{entry}}</li>
            {{/each}}
          </ul>
        {{else}}
          <p class="select-keyboard__transcript-empty">
            {{i18n "styleguide.sections.select.keyboard_transcript_empty"}}
          </p>
        {{/if}}
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
        <DSelect
          @identifier="sg-keyboard-clearing"
          @items={{this.locales}}
          @value={{this.clearableValue}}
          @onChange={{this.updateClearable}}
          @clearable={{true}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        />
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
        {{! The control is here to be narrowed, not to demonstrate the modal beside the popover:
      whether the overlay is a popover or a modal is decided by a global viewport signal rather
      than per instance, so the two cannot be shown side by side. Resizing is the only honest
      way to see it, and the deltas are stated rather than faked. }}
        <div class="select-examples__control">
          <DSelect
            @identifier="sg-keyboard-mobile"
            @items={{this.locales}}
            @value={{this.mobileValue}}
            @onChange={{this.updateMobile}}
            @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          />
        </div>

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
}
