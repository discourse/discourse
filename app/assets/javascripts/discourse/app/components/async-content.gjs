import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { TrackedAsyncData } from "ember-async-data";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";

export default class AsyncContent extends Component {
  #skipResolvingData = !this.args.loadOnInit;

  @cached
  get data() {
    const asyncData = this.args.asyncData;
    const context = this.args.context;

    let value;

    if (typeof asyncData === "function") {
      value =
        this.args.debounce && !this.#skipResolvingData
          ? new Promise((resolve, reject) => {
              discourseDebounce(
                this,
                this.#resolveAsyncData,
                asyncData,
                context,
                resolve,
                reject,
                this.args.debounce
              );
            })
          : this.#resolveAsyncData(asyncData, context);
    } else if (asyncData instanceof Promise) {
      value = asyncData;
    }

    if (!(value instanceof Promise)) {
      throw new Error(
        `\`<AsyncContent />\` expects @asyncData to be an async function or a promise`
      );
    }

    return new TrackedAsyncData(value);
  }

  // a stable reference to a function to use the `debounce` method
  // this function simply calls the asyncData function and resolves the promise if a resolve function is provided
  #resolveAsyncData(asyncData, context, resolve, reject) {
    if (this.#skipResolvingData) {
      this.#skipResolvingData = false;
      return Promise.resolve(null);
    }

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
    {{/if}}
    {{#if this.data.isResolved}}
      {{yield this.data.value to="content"}}
    {{/if}}
    {{#if this.data.isRejected}}
      {{#if (has-block "error")}}
        {{yield this.data.error to="error"}}
      {{else}}
        {{popupAjaxError this.data.error}}
      {{/if}}
    {{/if}}
  </template>
}
