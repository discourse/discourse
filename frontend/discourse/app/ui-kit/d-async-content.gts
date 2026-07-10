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
 * A function data source. It receives the `@context` value and an options
 * object carrying an `AbortSignal`, and returns either the resolved value
 * directly (a client-only data source) or a promise for it. Existing
 * zero/one-arg functions remain assignable because a function may declare
 * fewer parameters than it is called with.
 */
type AsyncDataFn<T> = (
  context: unknown,
  options: { signal: AbortSignal }
) => T | Promise<T>;

interface DAsyncContentSignature<T> {
  Args: {
    // Data source: a promise, an already-constructed `TrackedAsyncData`, or a
    // function that produces the value (sync or async, and receives an
    // `AbortSignal` so it can cancel a superseded request).
    asyncData: Promise<T> | TrackedAsyncData<T> | AsyncDataFn<T>;

    // An arbitrary value forwarded to the function form of `@asyncData`.
    context?: unknown;

    // Debounce the function form: `true` uses the default input delay, a number
    // sets the delay in milliseconds.
    debounce?: boolean | number;

    // Keep rendering the previously resolved value while a subsequent load is
    // pending, rather than reverting to the loading state.
    retainWhileReloading?: boolean;

    // How a rejection is surfaced when no `error` block is provided. Cannot be
    // combined with an `error` block.
    errorMode?: ErrorMode;
  };

  Blocks: {
    // Rendered while the data is pending (no default: a loading spinner).
    loading: [];

    // Rendered once resolved, yielding the resolved value.
    content: [value: T];

    // Rendered instead of `content` when the resolved value is falsy.
    empty: [];

    // Rendered on rejection, yielding the error and a component (pre-bound to
    // the error) that renders the default inline error message.
    error: [
      error: Error,
      retry: WithBoundArgs<typeof AsyncContentInlineError, "error">,
    ];
  };
}

export default class DAsyncContent<T> extends Component<
  DAsyncContentSignature<T>
> {
  #debounce: boolean | number | undefined = false;
  #abortController: AbortController | null = null;

  // The value from the most recent resolution, kept so we can keep rendering it
  // while a *subsequent* load is pending (opt-in via `@retainWhileReloading`).
  // Plain fields, not tracked: they are written from within the `resolution`
  // getter and only read back when the next load is pending, so they never need
  // to drive their own invalidation.
  #lastResolvedValue: T | undefined = undefined;
  #hasResolvedOnce = false;

  willDestroy(): void {
    super.willDestroy();
    this.#abortController?.abort();
  }

  /**
   * Resolves the current async state into a single render mode. Collapsing the
   * states into one getter (rather than branching on `data.isPending` /
   * `isResolved` directly in the template) lets the `:content` block stay
   * mounted across a pending→resolved transition when retaining: both phases
   * report `mode: "content"`, so Glimmer keeps the same DOM and the yielded
   * value simply updates in place.
   */
  @cached
  get resolution(): {
    mode: "idle" | "loading" | "content" | "error";
    value?: T;
    error?: Error;
  } {
    const data = this.data;

    if (!data) {
      return { mode: "idle" };
    }

    if (data.isResolved) {
      // Remember the resolved value so a later pending phase can keep showing
      // it. These are plain, untracked fields — writing them mid-computation
      // can't dirty a tag or trigger a re-render loop, which is what the
      // no-side-effects rule guards against.
      // `TrackedAsyncData` types `value` as `T | null`; in the resolved state it
      // is the resolved `T`, and a falsy value is routed to the `:empty` block,
      // so the `:content` block yields `T`.
      /* eslint-disable ember/no-side-effects */
      this.#lastResolvedValue = data.value as T;
      this.#hasResolvedOnce = true;
      /* eslint-enable ember/no-side-effects */
      return { mode: "content", value: data.value as T };
    }

    if (data.isRejected) {
      // `TrackedAsyncData` types `error` as `unknown`; the rejected state carries
      // the rejection reason, surfaced to the `:error` block and the inline error
      // display as `Error` (matching what consumers of that chain expect).
      return { mode: "error", error: data.error as Error };
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
  get data(): TrackedAsyncData<T> | undefined {
    const asyncData = this.args.asyncData;
    const context = this.args.context;

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (asyncData instanceof TrackedAsyncData) {
      return asyncData;
    }

    // Each (re)computation supersedes the previous fetch: abort the prior request so a
    // stale response is cancelled at the network layer, not merely ignored on render.
    // Consumers opt in by honoring the `signal` passed to their async function.
    const signal = this.#supersedeRequest();

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
              signal,
              resolve,
              reject,
              this.#debounce
            );
          })
        : this.#resolveAsyncData(asyncData, context, signal);
    }

    // A function may return a synchronous value (a client-only data source) rather
    // than a promise. `TrackedAsyncData` resolves a non-promise synchronously, so such
    // a source renders content with no pending/loading phase; a promise resolves
    // asynchronously as usual.
    //
    // The branch analysis above is exhaustive for the supported `@asyncData`
    // shapes, so `value` is always assigned; the cast drops the never-hit
    // `Promise<void>`/`undefined` members and pins the resolved type to `T`.
    return new TrackedAsyncData(value as T | Promise<T>);
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

  // Aborts the previous fetch's controller and mints a fresh one, returning its
  // signal. Kept out of the `data` getter body so the (benign, untracked) mutation
  // isn't a computed side-effect.
  #supersedeRequest(): AbortSignal {
    this.#abortController?.abort();
    this.#abortController = new AbortController();
    return this.#abortController.signal;
  }

  // a stable reference to a function to use the `debounce` method
  #resolveAsyncData(
    asyncData: AsyncDataFn<T>,
    context: unknown,
    signal: AbortSignal,
    resolve?: (value: T | PromiseLike<T>) => void,
    reject?: (reason?: unknown) => void
  ): T | Promise<T> | Promise<void> {
    this.#debounce =
      this.args.debounce === true ? INPUT_DELAY : this.args.debounce;

    // The async function receives an AbortSignal as a second arg so it can cancel an
    // in-flight request when superseded; existing zero/one-arg functions ignore it.
    // When a resolve fn is provided (the debounced path) we settle the outer promise;
    // otherwise we return the function's result directly (a promise OR a sync value).
    //
    // The debounced path only runs against async data sources, so the result is
    // cast to `Promise<T>` to settle the outer promise via `.then`/`.catch`.
    return resolve
      ? (asyncData(context, { signal }) as Promise<T>)
          .then(resolve)
          .catch(reject)
      : asyncData(context, { signal });
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
      {{! In error mode the resolution error is always present; this guard
          narrows it from a possibly-undefined value to a definite error for the
          yields and arguments below. }}
      {{#if this.resolution.error}}
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
