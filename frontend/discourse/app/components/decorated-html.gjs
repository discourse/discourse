import Component from "@glimmer/component";
import { untrack } from "@glimmer/validator";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import helperFn from "discourse/helpers/helper-fn";
import deprecated from "discourse/lib/deprecated";
import {
  isProduction,
  isRailsTesting,
  isTesting,
} from "discourse/lib/environment";
import { WIDGET_DECOMMISSION_OPTIONS } from "discourse/widgets/widget";

const detachedDocument = document.implementation.createHTMLDocument("detached");

/** @type {Symbol} Default decorator type used when no specific type is provided */
export const NON_STREAM_HTML_DECORATOR = Symbol("non-stream");

/** @type {Object.<Symbol|string, Function[]>} Storage for HTML decorators organized by type */
let htmlDecorators = {};

/**
 * Gets or initializes an array of HTML decorators for a specific type
 *
 * @param {Symbol|string} [type] - The decorator type to get decorators for. If not provided,
 *                                defaults to NON_STREAM_HTML_DECORATOR
 * @returns {Function[]} An array of decorator functions for the specified type
 * @example
 * const decorators = getHtmlDecoratorsForType(myDecoratorType);
 * // Returns existing decorators array or initializes a new one
 */
function getHtmlDecoratorsForType(type) {
  return (htmlDecorators[type ?? NON_STREAM_HTML_DECORATOR] ||= []);
}

/**
 * Registers a new HTML decorator function for a specific type of decoration.
 *
 * @param {Function} decorator - The decorator function to register. It receives two parameters:
 *                              1. element: HTMLElement to be decorated
 *                              2. options: Object containing decoration options
 *                              The decorator can optionally return a cleanup function.
 * @param {Symbol|string} [type=NON_STREAM_HTML_DECORATOR] - The type of decorator to register.
 *                                                       When not provided, defaults to NON_STREAM_HTML_DECORATOR (non-stream).
 * @returns {void}
 * @example
 * registerHtmlDecorator((element, options) => {
 *   element.classList.add('decorated');
 *   return () => element.classList.remove('decorated'); // Cleanup function
 * });
 */
export function registerHtmlDecorator(decorator, type) {
  getHtmlDecoratorsForType(type).push(decorator);
}

/**
 * Applies registered HTML decorators to a DOM element and returns their cleanup functions.
 *
 * @param {HTMLElement} element - The DOM element to apply decorators to
 * @param {Object} options - Options object passed to each decorator function
 * @param {Symbol|string} [type=NON_STREAM_HTML_DECORATOR] - The type of decorators to apply.
 *                                                       When not provided, defaults to NON_STREAM_HTML_DECORATOR (non-stream).
 * @returns {Function[]} Array of cleanup functions from decorators that returned them.
 *                      Each function, when called, will undo the decorator's effects.
 * @example
 * const cleanupFunctions = applyHtmlDecorators(
 *   document.querySelector('.content'),
 *   { highlight: true }
 * );
 *
 * // To clean up all decorations:
 * cleanupFunctions.forEach(cleanup => cleanup());
 */
export function applyHtmlDecorators(element, options, type) {
  return getHtmlDecoratorsForType(type)
    .map((decorator) => {
      return decorator(element, options);
    })
    .filter((fn) => typeof fn === "function");
}

/**
 * Clears all registered HTML decorators
 *
 * USE ONLY FOR TESTING PURPOSES
 *
 * @returns {void}
 */
export function resetHtmlDecorators() {
  if (isTesting()) {
    htmlDecorators = {};
  }
}

/**
 * Reactively renders cooked HTML with decorations applied.
 */
export default class DecoratedHtml extends Component {
  renderGlimmerInfos = new TrackedArray();

  decoratedContent = helperFn(({ decorateArgs }, on) => {
    const cookedDiv = this.elementToDecorate;

    const helper = new DecorateHtmlHelper({
      renderGlimmerInfos: this.renderGlimmerInfos,
      model: this.args.model,
      context: this.args.context,
    });
    on.cleanup(() => helper.teardown());

    const decorateFn = this.args.decorate;

    // force parameters explicity declarated in `decorateArgs` to be tracked despite the
    // use of `untrack` below
    decorateArgs && Object.values(decorateArgs);

    try {
      untrack(() => decorateFn?.(cookedDiv, helper, decorateArgs));
    } catch (e) {
      if (isRailsTesting() || isTesting()) {
        throw e;
      } else {
        // in case one of the decorators throws an error we want to surface it to the console but prevent
        // the application from crashing

        // eslint-disable-next-line no-console
        console.error(e);
      }
    }

    document.adoptNode(cookedDiv);

    return cookedDiv;
  });

  get elementToDecorate() {
    const cooked = this.args.html || htmlSafe("");
    if (!isHTMLSafe(cooked)) {
      throw "@cooked must be an htmlSafe string";
    }
    const cookedDiv = detachedDocument.createElement("div");
    cookedDiv.innerHTML = cooked.toString();

    if (this.args.id) {
      cookedDiv.id = this.args.id;
    }

    if (this.args.className) {
      cookedDiv.className = this.args.className;
    }
    return cookedDiv;
  }

  /**
   * Checks if a given HTML element belongs to the current document.
   * In development mode, it warns if the element is not in the document.
   *
   * This is used to ensure components added using `renderGlimmer` are only rendered in the same document, preventing
   * rendering errors that otherwise would crash the application.
   *
   * @param {Object} info - Object containing element information
   * @param {Element} info.element - The DOM element to check
   * @returns {boolean} True if element belongs to current document, false otherwise
   */
  isElementInDocument(info) {
    const result = info.element.ownerDocument === document;

    if (!isProduction() && !result) {
      // eslint-disable-next-line no-console
      console.warn(
        "The `renderGlimmer` definition below was unable to render the decorated HTML because the target element is not in the " +
          "current document. This likely occurred because the element was removed by another decorator.\n",
        info
      );
    }

    return result;
  }

  <template>
    {{~this.decoratedContent decorateArgs=@decorateArgs~}}

    {{~#each this.renderGlimmerInfos as |info|~}}
      {{~#if (this.isElementInDocument info)~}}
        {{~#if info.append}}
          {{~#in-element info.element insertBefore=null~}}
            <info.component @data={{info.data}} />
          {{~/in-element~}}
        {{~else}}
          {{~#in-element info.element~}}
            <info.component @data={{info.data}} />
          {{~/in-element~}}
        {{~/if}}
      {{~/if~}}
    {{~/each~}}
  </template>
}

class DecorateHtmlHelper {
  #renderGlimmerInfos;
  #model;
  #context;

  constructor({ renderGlimmerInfos, model, context }) {
    this.#renderGlimmerInfos = renderGlimmerInfos;
    this.#model = model;
    this.#context = context;
  }

  renderGlimmer(targetElement, component, data, opts = {}) {
    if (!(targetElement instanceof Element)) {
      deprecated(
        "Invalid `targetElement` passed to `helper.renderGlimmer` while using `api.decorateCookedElement` with the Glimmer Post Stream. `targetElement` must be a valid HTML element. This call has been ignored to prevent errors.",
        WIDGET_DECOMMISSION_OPTIONS
      );

      return;
    }

    if (component.name === "factory") {
      deprecated(
        "Invalid `component` passed to `helper.renderGlimmer` while using `api.decorateCookedElement` with the Glimmer Post Stream. `component` must be a valid Glimmer component. If using a template compiled via ember-cli-htmlbars, replace it with the `<template>...</template>` syntax. This call has been ignored to prevent errors.",
        WIDGET_DECOMMISSION_OPTIONS
      );

      return;
    }

    const info = {
      element: targetElement,
      component,
      data,
      append: opts.append ?? true,
    };
    this.#renderGlimmerInfos.push(info);
  }

  get model() {
    return this.#model;
  }

  get context() {
    return this.#context;
  }

  getModel() {
    return this.model;
  }

  get widget() {
    deprecated(
      "Using `helper.widget` has been decommissioned. See https://meta.discourse.org/t/372063/1",
      WIDGET_DECOMMISSION_OPTIONS
    );
  }

  teardown() {
    this.#renderGlimmerInfos.length = 0;
  }
}
