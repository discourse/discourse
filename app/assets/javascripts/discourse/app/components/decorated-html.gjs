import Component from "@glimmer/component";
import { untrack } from "@glimmer/validator";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import helperFn from "discourse/helpers/helper-fn";
import deprecated from "discourse/lib/deprecated";
import { POST_STREAM_DEPRECATION_OPTIONS } from "discourse/widgets/post-stream";

const detachedDocument = document.implementation.createHTMLDocument("detached");

/**
 * Reactively renders cooked HTML with decorations applied.
 */
export default class DecoratedHtml extends Component {
  renderGlimmerInfos = new TrackedArray();

  decoratedContent = helperFn((args, on) => {
    const cookedDiv = this.elementToDecorate;

    const helper = new DecorateHtmlHelper({
      renderGlimmerInfos: this.renderGlimmerInfos,
      model: this.args.model,
      context: this.args.context,
    });
    on.cleanup(() => helper.teardown());

    const decorateFn = this.args.decorate;
    untrack(() => decorateFn?.(cookedDiv, helper));

    document.adoptNode(cookedDiv);

    const afterAdoptDecorateFn = this.args.decorateAfterAdopt;
    untrack(() => afterAdoptDecorateFn?.(cookedDiv, helper));

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

  <template>
    {{~this.decoratedContent~}}

    {{~#each this.renderGlimmerInfos as |info|~}}
      {{~#if info.append}}
        {{~#in-element info.element insertBefore=null~}}
          <info.component @data={{info.data}} />
        {{~/in-element~}}
      {{~else}}
        {{~#in-element info.element~}}
          <info.component @data={{info.data}} />
        {{~/in-element~}}
      {{~/if}}
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
        POST_STREAM_DEPRECATION_OPTIONS
      );

      return;
    }

    if (component.name === "factory") {
      deprecated(
        "Invalid `component` passed to `helper.renderGlimmer` while using `api.decorateCookedElement` with the Glimmer Post Stream. `component` must be a valid Glimmer component. If using a template compiled via ember-cli-htmlbars, replace it with the `<template>...</template>` syntax. This call has been ignored to prevent errors.",
        POST_STREAM_DEPRECATION_OPTIONS
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

  // TODO (glimmer-post-stream): remove this when we remove the legacy post stream code
  get widget() {
    deprecated(
      "Accessing `helper.widget` is not supported when using `api.decorateCookedElement` with the Glimmer Post Stream and can yield unexpected results.",
      POST_STREAM_DEPRECATION_OPTIONS
    );

    const attrs = this.model;

    return {
      get attrs() {
        return attrs;
      },
      scheduleRerender() {
        // This is a no-op when using the new glimmer components.
        // The component will rerender automatically when the model changes.
      },
    };
  }

  teardown() {
    this.#renderGlimmerInfos.length = 0;
  }
}
