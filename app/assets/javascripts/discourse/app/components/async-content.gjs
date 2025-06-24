import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import { Promise as RsvpPromise } from "rsvp";
import { eq } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import FlashMessage from "discourse/components/flash-message";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { extractErrorInfo } from "../lib/ajax-error";

const ERROR_MODES = ["flash", "popup"];
const DEFAULT_ERROR_MODE = "flash";

export default class AsyncContent extends Component {
  #debounce = false;

  @cached
  get data() {
    const asyncData = this.args.asyncData;
    const context = this.args.context;

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (asyncData instanceof TrackedAsyncData) {
      return asyncData;
    }

    let value;

    if (this.#isPromise(asyncData)) {
      value = asyncData;
    } else if (typeof asyncData === "function") {
      value = this.#debounce
        ? new Promise((resolve, reject) => {
            discourseDebounce(
              this,
              this.#resolveAsyncData,
              asyncData,
              context,
              resolve,
              reject,
              this.#debounce
            );
          })
        : this.#resolveAsyncData(asyncData, context);
    }

    if (!this.#isPromise(value)) {
      throw new Error(
        `\`<AsyncContent />\` expects @asyncData to be an async function or a promise`
      );
    }

    return new TrackedAsyncData(value);
  }

  get errorMode() {
    return this.args.errorMode ?? DEFAULT_ERROR_MODE;
  }

  @bind
  verifyParameters({ hasErrorBlock }) {
    if (hasErrorBlock && this.args.errorMode) {
      throw `@errorMode cannot be used when a block named "error" is provided`;
    }

    if (this.errorMode && !ERROR_MODES.includes(this.errorMode)) {
      throw `@errorMode must be one of \`${ERROR_MODES.join("`, `")}\``;
    }
  }

  #isPromise(value) {
    return value instanceof Promise || value instanceof RsvpPromise;
  }

  // a stable reference to a function to use the `debounce` method
  #resolveAsyncData(asyncData, context, resolve, reject) {
    this.#debounce =
      this.args.debounce === true ? INPUT_DELAY : this.args.debounce;

    // when a resolve function is provided, we need to resolve the promise once asyncData is done
    // otherwise, we just call asyncData
    return resolve
      ? asyncData(context).then(resolve).catch(reject)
      : asyncData(context);
  }

  <template>
    {{this.verifyParameters (hash hasErrorBlock=(has-block "error"))}}
    {{#if this.data.isPending}}
      {{#if (has-block "loading")}}
        {{yield to="loading"}}
      {{else}}
        <ConditionalLoadingSpinner @condition={{this.data.isPending}} />
      {{/if}}
    {{else if this.data.isResolved}}
      {{#if this.data.value}}
        {{yield this.data.value to="content"}}
      {{else if (has-block "empty")}}
        {{yield to="empty"}}
      {{else}}
        {{yield this.data.value to="content"}}
      {{/if}}
    {{else if this.data.isRejected}}
      {{#if (has-block "error")}}
        {{yield
          this.data.error
          (component AsyncContentInlineError error=this.data.error)
          to="error"
        }}
      {{else if (eq this.errorMode "flash")}}
        <AsyncContentInlineError @error={{this.data.error}} />
      {{else if (eq this.errorMode "popup")}}
        {{popupAjaxError this.data.error}}
      {{/if}}
    {{/if}}
  </template>
}

class AsyncContentInlineError extends Component {
  get errorMessage() {
    const errorInfo = extractErrorInfo(this.args.error);
    return errorInfo.html ? htmlSafe(errorInfo.message) : errorInfo.message;
  }

  <template>
    <FlashMessage role="alert" @flash={{this.errorMessage}} @type="error" />
  </template>
}
