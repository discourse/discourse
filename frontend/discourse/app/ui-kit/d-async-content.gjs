import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import { Promise as RsvpPromise } from "rsvp";
import { extractErrorInfo, popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { eq } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DFlashMessage from "discourse/ui-kit/d-flash-message";

const ERROR_MODES = ["flash", "popup"];
const DEFAULT_ERROR_MODE = "flash";

export default class DAsyncContent extends Component {
  #debounce = false;

  // The value from the most recent resolution, kept so we can keep rendering it
  // while a *subsequent* load is pending (opt-in via `@retainWhileReloading`).
  // Plain fields, not tracked: they are written from within the `resolution`
  // getter and only read back when the next load is pending, so they never need
  // to drive their own invalidation.
  #lastResolvedValue = undefined;
  #hasResolvedOnce = false;

  /**
   * Resolves the current async state into a single render mode. Collapsing the
   * states into one getter (rather than branching on `data.isPending` /
   * `isResolved` directly in the template) lets the `:content` block stay
   * mounted across a pending→resolved transition when retaining: both phases
   * report `mode: "content"`, so Glimmer keeps the same DOM and the yielded
   * value simply updates in place.
   *
   * @returns {{mode: string, value?: *, error?: *}}
   */
  @cached
  get resolution() {
    const data = this.data;

    if (!data) {
      return { mode: "idle" };
    }

    if (data.isResolved) {
      // Remember the resolved value so a later pending phase can keep showing
      // it. These are plain, untracked fields — writing them mid-computation
      // can't dirty a tag or trigger a re-render loop, which is what the
      // no-side-effects rule guards against.
      /* eslint-disable ember/no-side-effects */
      this.#lastResolvedValue = data.value;
      this.#hasResolvedOnce = true;
      /* eslint-enable ember/no-side-effects */
      return { mode: "content", value: data.value };
    }

    if (data.isRejected) {
      return { mode: "error", error: data.error };
    }

    // Pending. When the consumer opts into `@retainWhileReloading`, keep showing
    // the last resolved value so the content subtree isn't unmounted on a reload
    // (useful when long-lived component state lives inside the `:content` block).
    if ((this.args.retainWhileReloading ?? false) && this.#hasResolvedOnce) {
      return { mode: "content", value: this.#lastResolvedValue };
    }

    return { mode: "loading" };
  }

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

    if (value && !this.#isPromise(value)) {
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
    {{#if (eq this.resolution.mode "loading")}}
      {{#if (has-block "loading")}}
        {{yield to="loading"}}
      {{else}}
        <DConditionalLoadingSpinner @condition={{true}} />
      {{/if}}
    {{else if (eq this.resolution.mode "content")}}
      {{#if this.resolution.value}}
        {{yield this.resolution.value to="content"}}
      {{else if (has-block "empty")}}
        {{yield to="empty"}}
      {{else}}
        {{yield this.resolution.value to="content"}}
      {{/if}}
    {{else if (eq this.resolution.mode "error")}}
      {{#if (has-block "error")}}
        {{yield
          this.resolution.error
          (component AsyncContentInlineError error=this.resolution.error)
          to="error"
        }}
      {{else if (eq this.errorMode "flash")}}
        <AsyncContentInlineError @error={{this.resolution.error}} />
      {{else if (eq this.errorMode "popup")}}
        {{popupAjaxError this.resolution.error}}
      {{/if}}
    {{/if}}
  </template>
}

class AsyncContentInlineError extends Component {
  get errorMessage() {
    const errorInfo = extractErrorInfo(this.args.error);
    return errorInfo.html ? trustHTML(errorInfo.message) : errorInfo.message;
  }

  <template>
    <DFlashMessage role="alert" @flash={{this.errorMessage}} @type="error" />
  </template>
}
