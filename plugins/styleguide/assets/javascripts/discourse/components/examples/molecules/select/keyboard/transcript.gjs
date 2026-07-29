import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

const MAX_ENTRIES = 6;

export default class KeyboardTranscriptSelectExample extends Component {
  @service a11y;

  @tracked entries = [];
  @tracked value = [];

  @action
  captureAnnouncement() {
    const message = this.a11y.politeMessage;
    if (message) {
      this.entries = [message, ...this.entries].slice(0, MAX_ENTRIES);
    }
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-keyboard-transcript"
      @items={{LOCALES}}
      @placement="top-start"
      @multiple={{true}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
    />

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
  </template>
}
