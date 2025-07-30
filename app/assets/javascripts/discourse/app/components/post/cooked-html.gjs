import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import curryComponent from "ember-curry-component";
import DecoratedHtml, {
  DETACHED_DOCUMENT,
} from "discourse/components/decorated-html";
import lazyHash from "discourse/helpers/lazy-hash";
import { bind } from "discourse/lib/decorators";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { makeArray } from "discourse/lib/helpers";
import decorateLinkCounts from "discourse/lib/post-cooked-html-decorators/link-counts";
import decorateMentions from "discourse/lib/post-cooked-html-decorators/mentions";
import decorateQuoteControls from "discourse/lib/post-cooked-html-decorators/quote-controls";
import decorateSearchHighlight from "discourse/lib/post-cooked-html-decorators/search-highlight";
import decorateSelectionBarrier from "discourse/lib/post-cooked-html-decorators/selection-barrier";
import decorateStatefulHtmlElements from "discourse/lib/post-cooked-html-decorators/stateful-html-elements";
import { i18n } from "discourse-i18n";

const POST_COOKED_DECORATORS_BEFORE_ADOPT = [
  decorateQuoteControls,
  decorateLinkCounts,
  decorateSearchHighlight,
];

const POST_COOKED_DECORATORS_AFTER_ADOPT = [
  decorateMentions,
  decorateStatefulHtmlElements,
];

export default class PostCookedHtml extends Component {
  @service appEvents;
  @service currentUser;

  #pendingCleanup = {};
  #decoratorState = this.args.decoratorState || new TrackedMap();

  willDestroy() {
    super.willDestroy(...arguments);
    this.#cleanupDecorations();
  }

  get isStreamElement() {
    return this.args.streamElement ?? false;
  }

  get shouldAddSelectionBarrier() {
    return this.args.selectionBarrier ?? true;
  }

  get className() {
    return this.args.className ?? "cooked";
  }

  get cooked() {
    if (this.isIgnored) {
      return i18n("post.ignored");
    }
    return this.args.cooked ?? this.args.post.cooked;
  }

  get highlightTerm() {
    return this.args.highlightTerm;
  }

  get extraDecorators() {
    return makeArray(this.args.extraDecorators);
  }

  get extraDecoratorsAfterAdopt() {
    return makeArray(this.args.extraDecoratorsAfterAdopt);
  }

  get ignoredUsers() {
    return this.currentUser?.ignored_users;
  }

  get isIgnored() {
    return (
      (this.args.post.firstPost || this.args.embeddedPost) &&
      this.ignoredUsers?.includes?.(this.args.post.username)
    );
  }

  @bind
  decorateBeforeAdopt(element, helper, args) {
    const decorators = [
      ...POST_COOKED_DECORATORS_BEFORE_ADOPT,
      ...this.extraDecorators,
    ];

    if (this.shouldAddSelectionBarrier) {
      decorators.push(decorateSelectionBarrier);
    }

    const eventName = this.isStreamElement
      ? "decorate-post-cooked-element:before-adopt"
      : "decorate-non-stream-cooked-element";

    this.#decorate("beforeAdopt", {
      element,
      helper,
      decorators,
      extraDecorators: this.extraDecorators,
      args,
      decorateCookedEvent: eventName,
    });
  }

  @bind
  decorateAfterAdopt(element, helper, args) {
    const decorators = [
      ...POST_COOKED_DECORATORS_AFTER_ADOPT,
      ...this.extraDecoratorsAfterAdopt,
    ];

    const eventName = this.isStreamElement
      ? "decorate-post-cooked-element:after-adopt"
      : null;

    this.#decorate("afterAdopt", {
      element,
      helper,
      decorators,
      extraDecorators: this.extraDecoratorsAfterAdopt,
      args,
      decorateCookedEvent: eventName,
    });
  }

  /**
   * Safely executes a function and handles errors appropriately for testing vs production
   * @param {Function} fn - Function to execute
   * @private
   */
  #safeExecute(fn) {
    try {
      return fn();
    } catch (e) {
      if (isRailsTesting() || isTesting()) {
        throw e;
      } else {
        // eslint-disable-next-line no-console
        console.error(e);
      }
    }
  }

  /**
   * Gets or creates decorator state for a given decorator function
   * @param {Function} decorator - The decorator function to get state for
   * @returns {TrackedMap} The decorator's state storage
   * @private
   */
  #getDecoratorState(decorator) {
    if (this.#decoratorState.has(decorator)) {
      return this.#decoratorState.get(decorator);
    }

    // Create new state storage for this decorator
    const decoratorState = new TrackedMap();
    this.#decoratorState.set(decorator, decoratorState);
    return decoratorState;
  }

  /**
   * Creates the context object passed to decorator functions
   * @param {HTMLElement} element - The DOM element being decorated
   * @param {Object} helper - Helper object containing utility functions
   * @param {Object} args - Arguments passed to the decorator
   * @param {TrackedMap} decoratorState - State storage for the decorator
   * @param {Array<Function>} extraDecorators - Additional decorator functions
   * @returns {Object} The decorator context object
   * @private
   */
  #createDecoratorContext(
    element,
    helper,
    args,
    decoratorState,
    extraDecorators
  ) {
    const owner = getOwner(this);

    return {
      cooked: this.cooked,
      createDetachedElement: this.#createDetachedElement,
      currentUser: this.currentUser,
      decoratorState,
      extraDecorators: this.extraDecorators,
      helper,
      highlightTerm: args.highlightTerm,
      ignoredUsers: args.ignoredUsers,
      isIgnored: args.isIgnored,
      owner,
      post: this.args.post,
      renderGlimmer: helper.renderGlimmer,
      renderNestedPostCookedHtml: this.#renderNestedPostCookedHtml(helper, {
        args,
        decoratorState,
        decorators: extraDecorators,
        isStreamElement: this.isStreamElement,
        owner,
      }),
      streamElement: this.isStreamElement,
    };
  }

  /**
   * Stores cleanup function for a decoration phase
   * @param {string} phase - The decoration phase ('beforeAdopt' or 'afterAdopt')
   * @param {Function} cleanupFn - The cleanup function to store
   * @private
   */
  #storeCleanupFunction(phase, cleanupFn) {
    if (!this.#pendingCleanup[phase]) {
      this.#pendingCleanup[phase] = [];
    }
    this.#pendingCleanup[phase].push(cleanupFn);
  }

  /**
   * Cleans up any pending decorations for specified phases.
   *
   * @param {string|string[]|undefined} filter - Optional phase(s) to clean up. If not provided, cleans up all phases.
   * @private
   */
  #cleanupDecorations(filter) {
    // Convert filter to array if single phase provided, or use all phase keys if no filter
    const phases = makeArray(filter || Object.keys(this.#pendingCleanup));
    phases.forEach((phase) => {
      if (!this.#pendingCleanup[phase]?.length) {
        // Skip if no cleanup functions exist for this phase
        return;
      }
      // Execute all cleanup functions and reset the array
      this.#pendingCleanup[phase].forEach((teardown) => teardown());
      this.#pendingCleanup[phase] = [];
    });
  }

  /**
   * Creates a detached DOM element with the specified node name
   *
   * @param {string} nodeName - The name of the DOM node to create
   * @returns {HTMLElement} A new detached DOM element
   * @private
   */
  #createDetachedElement(nodeName) {
    return DETACHED_DOCUMENT.createElement(nodeName);
  }

  /**
   * Applies decorators to the cooked HTML element
   *
   * @param {string} phase - The decoration phase ('beforeAdopt' or 'afterAdopt')
   * @param {Object} options - The decoration options
   * @param {HTMLElement} options.element - The DOM element to decorate
   * @param {Object} options.helper - Helper object containing utility functions
   * @param {Array<Function>} options.decorators - List of decorator functions to apply
   * @param {Array<Function>} options.extraDecorators - Additional decorator functions
   * @param {Object} options.args - Arguments passed to decorators
   * @param {string|null} options.decorateCookedEvent - Event name to trigger after decoration
   * @private
   */
  #decorate(
    phase,
    { element, helper, decorators, extraDecorators, args, decorateCookedEvent }
  ) {
    // Clean up any existing decorations for this phase
    this.#cleanupDecorations(phase);

    decorators.forEach((decorator) => {
      this.#safeExecute(() => {
        const decoratorState = this.#getDecoratorState(decorator);
        const context = this.#createDecoratorContext(
          element,
          helper,
          args,
          decoratorState,
          extraDecorators
        );
        const decorationCleanup = decorator(element, context);

        // Store cleanup function if the decorator returned one
        if (typeof decorationCleanup === "function") {
          this.#storeCleanupFunction(phase, decorationCleanup);
        }
      });
    });

    // Trigger an event to handle the decorations added using `api.decorateCooked`
    if (decorateCookedEvent) {
      this.#safeExecute(() => {
        this.appEvents.trigger(decorateCookedEvent, element, helper);
      });
    }
  }

  /**
   * Renders a nested PostCookedHtml component inside the specified element.
   *
   * @param {Object} helper - Helper object containing utility functions
   * @param {Object} options - Configuration options
   * @param {Object} options.args - Arguments passed from parent component
   * @param {TrackedMap} options.decoratorState - State storage for decorators
   * @param {Array<Function>} options.decorators - List of decorator functions to apply
   * @param {Array<Function>} options.decoratorsAfterAdopt - List of decorator functions to apply after adoption
   * @param {boolean} options.streamElement - Whether this is a stream element
   * @param {Object} options.owner - The owner of the component
   * @returns {Function} A function that renders the nested PostCookedHtml component
   * @private
   */
  #renderNestedPostCookedHtml(
    helper,
    {
      args,
      decoratorState,
      decorators,
      decoratorsAfterAdopt,
      streamElement,
      owner,
    }
  ) {
    return (
      element,
      post,
      { extraDecorators, extraDecoratorsAfterAdopt, extraArguments }
    ) => {
      // Merge base arguments with extra arguments and post details
      const nestedArguments = {
        ...extraArguments,
        post,
        decoratorState,
        streamElement,
        highlightTerm: args.highlightTerm,
        // Combine base decorators with any extra decorators passed
        extraDecorators: [...decorators, ...makeArray(extraDecorators)],
        // Combine base after-adopt decorators with any extra after-adopt decorators
        extraDecoratorsAfterAdopt: [
          ...decoratorsAfterAdopt,
          ...makeArray(extraDecoratorsAfterAdopt),
        ],
      };

      // Render a new PostCookedHtml component inside the element
      helper.renderGlimmer(
        element,
        curryComponent(PostCookedHtml, nestedArguments, owner)
      );
    };
  }

  <template>
    <DecoratedHtml
      @className={{this.className}}
      @decorate={{this.decorateBeforeAdopt}}
      @decorateAfterAdopt={{this.decorateAfterAdopt}}
      @decorateArgs={{lazyHash
        highlightTerm=this.highlightTerm
        isIgnored=this.isIgnored
        ignoredUsers=this.ignoredUsers
      }}
      @html={{htmlSafe this.cooked}}
      @model={{@post}}
    />
  </template>
}
