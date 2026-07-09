import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import {
  buildEventBlock,
  buildParams,
  getCustomFieldNames,
  parseEventAttrs,
  parseEventBlock,
  stateToEventInput,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";
import CompactEventEditor from "./compact-event-editor";

export default class ComposerEventEditor extends Component {
  @service appEvents;
  @service composer;
  @service currentUser;
  @service siteSettings;

  #pendingState = null;
  #wrapperElement = null;

  get initialState() {
    const raw = this.composer?.model?.reply || "";
    const parsed = parseEventBlock(raw);
    if (!parsed) {
      return null;
    }
    return {
      ...parseEventAttrs(parsed.attrs, {
        fallbackTimezone: this.currentUser?.user_option?.timezone,
        customFieldNames: getCustomFieldNames(this.siteSettings),
      }),
      description: parsed.description || "",
    };
  }

  @action
  urlTester(value) {
    return /^(https?:\/\/|www\.|mailto:)/i.test(value);
  }

  @action
  onChange(state) {
    this.#pendingState = state;
  }

  @action
  attachWrapper(element) {
    this.#wrapperElement = element;
    element.addEventListener("focusout", this.onFocusOut);
  }

  @action
  detachWrapper(element) {
    element.removeEventListener("focusout", this.onFocusOut);
    this.flush();
  }

  @action
  onFocusOut(event) {
    if (
      !this.#wrapperElement ||
      this.#wrapperElement.contains(event.relatedTarget)
    ) {
      return;
    }
    this.flush();
  }

  @action
  flush() {
    if (!this.#pendingState) {
      return;
    }
    const state = this.#pendingState;
    this.#pendingState = null;

    const raw = this.composer?.model?.reply || "";
    const parsed = parseEventBlock(raw);
    if (!parsed) {
      return;
    }

    const params = buildParams(
      state.startsAt,
      state.endsAt,
      stateToEventInput(state),
      this.siteSettings
    );
    delete params.description;

    const newBlock = buildEventBlock(params, state.description);
    if (newBlock === parsed.full) {
      return;
    }
    this.appEvents.trigger("composer:replace-text", parsed.full, newBlock, {
      skipNewSelection: true,
      skipFocus: true,
    });
  }

  @action
  onDelete() {
    this.#pendingState = null;
    const raw = this.composer?.model?.reply || "";
    const parsed = parseEventBlock(raw);
    if (parsed) {
      this.appEvents.trigger("composer:replace-text", parsed.full, "", {
        skipNewSelection: true,
      });
    }
  }

  <template>
    <div
      class="composer-event-node composer-event-editor"
      {{didInsert this.attachWrapper}}
      {{willDestroy this.detachWrapper}}
    >
      <CompactEventEditor
        @initialState={{this.initialState}}
        @urlTester={{this.urlTester}}
        @onChange={{this.onChange}}
        @onCommit={{this.flush}}
        @onDelete={{this.onDelete}}
      />
    </div>
  </template>
}
