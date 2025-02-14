import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { TrackedAsyncData } from "ember-async-data";
import { Promise as RsvpPromise } from "rsvp";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

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

  #isPromise(value) {
    return value instanceof Promise || value instanceof RsvpPromise;
  }

  // a stable reference to a function to use the `debounce` method
  #resolveAsyncData(asyncData, context, resolve, reject) {
    this.#debounce =
      this.args.debounce === true ? INPUT_DELAY : this.args.debounce;

    // when a resolve function is provided, we need to resolve the promise, once asyncData is done
    // otherwise, we just call asyncData
    return resolve
      ? asyncData(context).then(resolve).catch(reject)
      : asyncData(context);
  }

  <template>
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
        {{yield this.data.error to="error"}}
      {{else}}
        {{popupAjaxError this.data.error}}
      {{/if}}
    {{/if}}
  </template>
}
