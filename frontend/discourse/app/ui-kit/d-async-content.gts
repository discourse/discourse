import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { type TrustedHTML, trustHTML } from "@ember/template";
import type { WithBoundArgs } from "@glint/template";
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

type ErrorMode = "flash" | "popup";

/**
 * A function data source. It receives the `@context` value and returns either
 * the resolved value directly (a client-only data source) or a promise for it.
 */
type AsyncDataFn<T> = (context: unknown) => T | Promise<T>;

interface DAsyncContentSignature<T> {
  Args: {
    /**
     * The source of the data to render. One of:
     * - a `Promise` that resolves to the value;
     * - an already-constructed `TrackedAsyncData`, when the caller manages the
     *   async state itself;
     * - a function returning the value, or a promise for it, re-invoked
     *   whenever the tracked state it reads (including `@context`) changes.
     */
    asyncData: Promise<T> | TrackedAsyncData<T> | AsyncDataFn<T>;

    /**
     * A value forwarded to the function form of `@asyncData`. It is tracked, so
     * updating it re-invokes the function and reloads the data. Pass the
     * reactive state the data source depends on here to refresh the content
     * when that state changes.
     */
    context?: unknown;

    /**
     * Whether to debounce re-invocations of the function form of `@asyncData`,
     * so rapidly changing input does not refetch on every change. `true` uses
     * the default input delay; a number sets the delay in milliseconds.
     */
    debounce?: boolean | number;

    /**
     * How a rejection is surfaced when no `error` block is provided. Cannot be
     * combined with an `error` block.
     */
    errorMode?: ErrorMode;
  };

  Blocks: {
    /**
     * Rendered while the data is pending. When omitted, a loading spinner is
     * shown in its place.
     */
    loading: [];

    /** Rendered once the data resolves. */
    content: [
      /** The resolved value. */
      value: T,
    ];

    /** Rendered in place of `content` when the resolved value is falsy. */
    empty: [];

    /**
     * Rendered when the data rejects. When omitted, the rejection is handled
     * according to `@errorMode`.
     */
    error: [
      /** The rejection reason. */
      error: Error,

      /**
       * A component, pre-bound to the error, that renders the default inline
       * error message.
       */
      retry: WithBoundArgs<typeof AsyncContentInlineError, "error">,
    ];
  };
}

export default class DAsyncContent<T> extends Component<
  DAsyncContentSignature<T>
> {
  #debounce: boolean | number | undefined = false;

  @cached
  get data(): TrackedAsyncData<T> | undefined {
    const asyncData = this.args.asyncData;
    const context = this.args.context;

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (asyncData instanceof TrackedAsyncData) {
      return asyncData;
    }

    let value: T | Promise<T> | Promise<void> | undefined;

    if (this.#isPromise(asyncData)) {
      value = asyncData;
    } else if (typeof asyncData === "function") {
      value = this.#debounce
        ? new Promise<T>((resolve, reject) => {
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

    // The branch analysis above is exhaustive for the supported `@asyncData`
    // shapes, so `value` is always assigned; the cast drops the never-hit
    // `Promise<void>`/`undefined` members and pins the resolved type to `T`.
    return new TrackedAsyncData(value as T | Promise<T>);
  }

  // The rejection reason. `TrackedAsyncData` types `error` as `unknown`; the
  // rejected state carries the rejection reason, surfaced to the `:error` block
  // and the inline error display as `Error` (matching what consumers expect).
  get rejection(): Error {
    return this.data?.error as Error;
  }

  get errorMode(): ErrorMode {
    return this.args.errorMode ?? DEFAULT_ERROR_MODE;
  }

  @bind
  verifyParameters({ hasErrorBlock }: { hasErrorBlock: boolean }) {
    if (hasErrorBlock && this.args.errorMode) {
      throw `@errorMode cannot be used when a block named "error" is provided`;
    }

    if (this.errorMode && !ERROR_MODES.includes(this.errorMode)) {
      throw `@errorMode must be one of \`${ERROR_MODES.join("`, `")}\``;
    }
  }

  #isPromise(value: unknown): value is Promise<T> {
    return value instanceof Promise || value instanceof RsvpPromise;
  }

  // a stable reference to a function to use the `debounce` method
  #resolveAsyncData(
    asyncData: AsyncDataFn<T>,
    context: unknown,
    resolve?: (value: T | PromiseLike<T>) => void,
    reject?: (reason?: unknown) => void
  ): T | Promise<T> | Promise<void> {
    this.#debounce =
      this.args.debounce === true ? INPUT_DELAY : this.args.debounce;

    // when a resolve function is provided, we need to resolve the promise once asyncData is done
    // otherwise, we just call asyncData
    //
    // The debounced path only runs against async data sources, so the result is
    // cast to `Promise<T>` to settle the outer promise via `.then`/`.catch`.
    return resolve
      ? (asyncData(context) as Promise<T>).then(resolve).catch(reject)
      : asyncData(context);
  }

  <template>
    {{this.verifyParameters (hash hasErrorBlock=(has-block "error"))}}
    {{#if this.data.isPending}}
      {{#if (has-block "loading")}}
        {{yield to="loading"}}
      {{else}}
        <DConditionalLoadingSpinner @condition={{this.data.isPending}} />
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
          this.rejection
          (component AsyncContentInlineError error=this.rejection)
          to="error"
        }}
      {{else if (eq this.errorMode "flash")}}
        <AsyncContentInlineError @error={{this.rejection}} />
      {{else if (eq this.errorMode "popup")}}
        {{popupAjaxError this.rejection}}
      {{/if}}
    {{/if}}
  </template>
}

interface AsyncContentInlineErrorSignature {
  Args: {
    error: Error;
  };
}

class AsyncContentInlineError extends Component<AsyncContentInlineErrorSignature> {
  get errorMessage(): string | TrustedHTML {
    // `extractErrorInfo` is authored in untyped `.js`; annotate the fields we
    // read so the getter's return type stays precise rather than widening to `any`.
    const errorInfo: { html: boolean; message: string } = extractErrorInfo(
      this.args.error
    );
    return errorInfo.html ? trustHTML(errorInfo.message) : errorInfo.message;
  }

  <template>
    <DFlashMessage role="alert" @flash={{this.errorMessage}} @type="error" />
  </template>
}
