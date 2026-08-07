import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { cancel } from "@ember/runloop";
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
 * A function data source, re-invoked whenever the tracked state it reads
 * (including `@context`) changes. Returns the value or a promise for it.
 */
type AsyncDataFn<T> = (
  /** The value passed through `@context`. */
  context: unknown,
  /** Per-call values passed alongside `@context`. */
  options: {
    /**
     * Aborted when a later call supersedes this one. Forward it to your request
     * (e.g. `fetch`) to cancel the superseded work; ignoring it is fine.
     */
    signal: AbortSignal;
  }
) => T | Promise<T>;

interface DAsyncContentSignature<T> {
  Args: {
    /**
     * The source of the data to render. One of:
     * - a `Promise` that resolves to the value;
     * - an already-constructed `TrackedAsyncData`, when the caller manages the
     *   async state itself;
     * - an `AsyncDataFn` that produces the value on demand.
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
     *
     * The first evaluation is never debounced: there is no rapid input to
     * coalesce yet, and delaying it would only postpone the initial paint. The
     * delay applies from the second evaluation onward.
     *
     * A debounced re-invocation runs from a timer, outside the computation that
     * produces the data, so state the function reads there is *not* autotracked
     * and changing it will not reload. Only an un-debounced evaluation tracks
     * such reads, so a source that is ever debounced must never rely on
     * autotracking: pass every reactive dependency it has through `@context`.
     */
    debounce?: boolean | number;

    /**
     * Keep rendering the previously resolved value while a subsequent load is
     * pending, rather than reverting to the loading state.
     */
    retainWhileReloading?: boolean;

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
  #abortController: AbortController | null = null;

  // Whether the function form of `@asyncData` has been evaluated at least once, so the
  // first evaluation can skip debouncing: there is no rapid input to coalesce yet, and a
  // delay there would only postpone the initial paint.
  #hasEvaluated = false;

  // The value from the most recent resolution, kept so we can keep rendering it
  // while a *subsequent* load is pending (opt-in via `@retainWhileReloading`).
  // Plain fields, not tracked: they are written from within the `resolution`
  // getter and only read back when the next load is pending, so they never need
  // to drive their own invalidation.
  #lastResolvedValue: T | undefined = undefined;
  #hasResolvedOnce = false;

  // The scheduled debounced invocation and the settle functions of the promise standing
  // in for it, kept so a superseded or cancelled evaluation can still be settled.
  #debounceTimer: Parameters<typeof cancel>[0] = undefined;
  #pendingResolve: ((value: T | PromiseLike<T>) => void) | null = null;
  #pendingReject: ((reason?: unknown) => void) | null = null;

  willDestroy(): void {
    super.willDestroy();
    this.#abortController?.abort();
    this.#cancelPendingDebounce();
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
      // An externally-managed instance produces nothing for a superseded promise to
      // adopt, so the scheduled call is simply dropped and its promise settled.
      this.#cancelPendingDebounce();
      return asyncData;
    }

    // Each (re)computation supersedes the previous fetch: abort the prior request so a
    // stale response is cancelled at the network layer, not merely ignored on render.
    // Consumers opt in by honoring the `signal` passed to their async function.
    const signal = this.#supersedeRequest();

    let value: T | Promise<T> | Promise<void> | undefined;

    // This evaluation supersedes any call still waiting on its timer, whatever shape
    // `@asyncData` now has, so drop that call and keep hold of the promise standing in
    // for it. That promise then adopts this evaluation's outcome: cancelling its timer
    // removed the only thing that would have settled it, and the `TrackedAsyncData`
    // built on it would otherwise stay pending for good.
    const superseded = this.#takePendingDebounce();

    if (this.#isPromise(asyncData)) {
      value = asyncData;
    } else if (typeof asyncData === "function") {
      const debounceDelay = this.#debounceDelay;

      value = debounceDelay
        ? this.#scheduleDebounced(asyncData, context, signal, debounceDelay)
        : this.#resolveAsyncData(asyncData, context, signal);

      // Untracked, like the retained-value fields above: it only gates the *next*
      // evaluation, so it never needs to drive its own invalidation.
      /* eslint-disable-next-line ember/no-side-effects */
      this.#hasEvaluated = true;
    }

    superseded?.(value as T | Promise<T>);

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

  // Resolved at evaluation time rather than recorded as a side effect of the previous
  // resolve, so a changed `@debounce` reaches the very next evaluation instead of the
  // one after it.
  get #debounceDelay(): number | undefined {
    if (!this.#hasEvaluated) {
      return undefined;
    }

    const { debounce } = this.args;
    return debounce === true ? INPUT_DELAY : debounce || undefined;
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

  // Creates the promise standing in for a deferred call, then schedules that call.
  #scheduleDebounced(
    asyncData: AsyncDataFn<T>,
    context: unknown,
    signal: AbortSignal,
    delay: number
  ): Promise<T> {
    let resolve!: (value: T | PromiseLike<T>) => void;
    let reject!: (reason?: unknown) => void;

    const promise = new Promise<T>((resolveFn, rejectFn) => {
      resolve = resolveFn;
      reject = rejectFn;
    });

    this.#pendingResolve = resolve;
    this.#pendingReject = reject;
    this.#debounceTimer = discourseDebounce(
      this,
      this.#resolveAsyncData,
      asyncData,
      context,
      signal,
      resolve,
      reject,
      delay
    );

    return promise;
  }

  // Drops a call still waiting on its timer and hands back the `resolve` of the promise
  // standing in for it, so the caller can settle that promise with whatever supersedes
  // it. Returns `undefined` when no call is scheduled.
  #takePendingDebounce(): ((value: T | PromiseLike<T>) => void) | undefined {
    if (this.#debounceTimer == null) {
      return undefined;
    }

    cancel(this.#debounceTimer);
    this.#debounceTimer = undefined;

    const resolve = this.#pendingResolve ?? undefined;
    this.#pendingResolve = null;
    this.#pendingReject = null;

    return resolve;
  }

  // Drops a scheduled call when nothing is left to hand its promise, and rejects that
  // promise: nothing remains to settle it once its timer is cancelled, and the
  // `TrackedAsyncData` built on it would stay pending for good. The rejection is never
  // rendered, since the instance it backs is no longer the one `data` returns.
  #cancelPendingDebounce(): void {
    if (this.#debounceTimer == null) {
      return;
    }

    const reject = this.#pendingReject;
    cancel(this.#debounceTimer);
    this.#debounceTimer = undefined;
    this.#pendingResolve = null;
    this.#pendingReject = null;

    reject?.(new Error("The load was cancelled before it ran"));
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
    // The async function receives an AbortSignal as a second arg so it can cancel an
    // in-flight request when superseded; existing zero/one-arg functions ignore it.
    if (!resolve) {
      // The un-debounced path returns the function's result directly (a promise OR a
      // sync value), so a synchronous source still resolves with no pending phase.
      // A synchronous throw is turned into a rejection because it would otherwise
      // propagate out of the `data` getter and break the render instead of reaching
      // the error block. This path also serves the first evaluation of a debounced
      // source, which is never debounced.
      try {
        return asyncData(context, { signal });
      } catch (error) {
        return Promise.reject<T>(error);
      }
    }

    // The debounced path settles the outer promise that stands in for the deferred
    // call. It may run against a synchronous source, so the result can be a plain
    // value rather than a promise. Calling the source *inside* the executor both
    // assimilates either shape and converts a synchronous throw into a rejection —
    // `Promise.resolve(fn())` evaluates `fn()` first, so a throw there escapes the
    // debounce timer and leaves the outer promise unsettled forever.
    return new Promise<T>((settle) => settle(asyncData(context, { signal })))
      .then(resolve)
      .catch(reject);
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
