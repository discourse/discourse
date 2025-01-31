import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";

export default class AsyncContent extends Component {
  @tracked promise;
  @tracked fullfilled;
  @tracked rejected;

  @tracked error;
  @tracked data;

  promiseId = 0;

  constructor() {
    super(...arguments);

    if (this.args.loadOnInit ?? true) {
      this.reload(this.args.context);
    }
  }

  @action
  reload(context, opts) {
    this.fullfilled = false;
    this.rejected = false;

    const currentPromiseId = ++this.promiseId;

    if (typeof this.args.asyncData === "function") {
      this.promise = this.args.asyncData(context, opts);
    } else if (this.args.asyncData instanceof Promise) {
      this.promise = this.args.asyncData;
    }

    if (!(this.promise instanceof Promise)) {
      throw new Error(
        `\`<AsyncContent />\` expects @asyncData to be an async function or a promise`
      );
    }

    this.promise
      ?.then((data) => {
        if (this.promiseId === currentPromiseId) {
          this.fullfilled = true;
          this.data = data;
        }
      })
      ?.catch((error) => {
        if (this.promiseId === currentPromiseId) {
          this.rejected = true;
          this.error = error;
        }
      });
  }

  @action
  reset() {
    if (this.args.debounce) {
      return discourseDebounce(
        this,
        this.reload,
        this.args.context,
        this.args.debounce
      );
    }

    return this.reload(this.args.context);
  }

  get pending() {
    return this.promise && !this.fullfilled && !this.rejected;
  }

  <template>
    <div
      class="async-content-container"
      ...attributes
      {{didUpdate this.reset @asyncData @context}}
    >
      {{#if (has-block "loading")}}
        {{#if this.pending}}
          {{yield to="loading"}}
        {{/if}}
        {{#if this.fullfilled}}
          {{yield this.data to="content"}}
        {{/if}}
        {{#if this.rejected}}
          {{#if (has-block "error")}}
            {{yield this.error to="error"}}
          {{else}}
            {{popupAjaxError this.error}}
          {{/if}}
        {{/if}}
      {{else}}
        <ConditionalLoadingSpinner ...attributes @condition={{this.pending}}>
          {{#if this.fullfilled}}
            {{yield this.data to="content"}}
          {{/if}}
          {{#if this.rejected}}
            {{#if (has-block "error")}}
              {{yield this.error to="error"}}
            {{else}}
              {{popupAjaxError this.error}}
            {{/if}}
          {{/if}}
        </ConditionalLoadingSpinner>
      {{/if}}
    </div>
  </template>
}
