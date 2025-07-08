import { hasInternalComponentManager } from "@glimmer/manager";
import { h } from "virtual-dom";
import deprecated from "discourse/lib/deprecated";
import Connector from "discourse/widgets/connector";
import PostCooked from "discourse/widgets/post-cooked";
import { POST_STREAM_DEPRECATION_OPTIONS } from "discourse/widgets/post-stream";
import RawHtml from "discourse/widgets/raw-html";
import RenderGlimmer from "discourse/widgets/render-glimmer";

class DecoratorHelper {
  constructor(widget, attrs, state) {
    this.widget = widget;
    this.attrs = attrs;
    this.canConnectComponent = true;
    this.state = state;
    this.register = widget.register;
    this.register.deprecateContainer(this);
  }

  /**
   * The `h` helper allows you to build up a virtual dom easily.
   *
   * Example:
   *
   * ```
   * // renders `<div class='some-class'><p>paragraph</p></div>`
   * return helper.h('div.some-class', helper.h('p', 'paragraph'));
   * ```
   * Check out  https://github.com/Matt-Esch/virtual-dom/blob/master/virtual-hyperscript/README.md
   * for more details on how to construct markup with h.
   **/
  // h() is attached via `prototype` below

  /**
   * Attach another widget inside this one.
   *
   * ```
   * return helper.attach('widget-name');
   * ```
   */
  attach(name, attrs, state) {
    attrs = attrs || this.widget.attrs;
    state = state || this.widget.state;

    return this.widget.attach(name, attrs, state);
  }

  get model() {
    return this.widget.findAncestorModel();
  }

  /**
   * Returns the model associated with this widget. When decorating
   * posts this will normally be the post.
   *
   * Example:
   *
   * ```
   * const post = helper.getModel();
   * console.log(post.get('id'));
   * ```
   **/
  getModel() {
    return this.model;
  }

  /**
   * If your decorator must produce raw HTML, you can use this helper
   * to display it. It is preferred to use the `h` helper and create
   * the HTML yourself whenever possible.
   *
   * Example:
   *
   * ```
   * return helper.rawHtml(`<p>I will be displayed</p`);
   * ```
   **/
  rawHtml(html) {
    return new RawHtml({ html });
  }

  /**
   * Renders `cooked` content using all the helpers and decorators that
   * are attached to that. This is useful if you want to render a post's
   * content or a different version of it.
   *
   * Example:
   *
   * ```
   * return helper.cooked(`<p>Cook me</p>`);
   * ```
   **/
  cooked(cooked) {
    return new PostCooked({ cooked }, this);
  }

  /**
   * You can use this bridge to mount an Ember Component inside the virtual
   * DOM post stream. Note that this is a bit bizarre, as our core app
   * is rendered in Ember, then we switch to a virtual dom, and this
   * allows part of that virtual dom to use Ember again!
   *
   * It really only exists as backwards compatibility for some old
   * plugins that would be difficult to update otherwise. There are
   * performance reasons not to use this, so be careful and avoid
   * using it whenever possible.
   *
   * Example:
   *
   * ```
   * helper.connect({ component: 'my-component-name' });
   * ```
   **/
  connect(details) {
    return new Connector(this.widget, details);
  }

  /**
   * Returns an element containing a rendered glimmer template. For full usage instructions,
   * see `widgets/render-glimmer.js`.
   *
   * DEPRECATION NOTICES:
   * - using a string describing a new wrapper element as the `targetElement` parameter is deprecated.
   *   Use an existing HTML element instead.
   * - using a template compiled via `ember-cli-htmlbars` as the `component` parameter is deprecated.
   *   You should provide a component instead.
   *
   * Example usage in a `.gjs` file:
   *
   * ```
   * api.decorateCookedElement((cooked, helper) => {
   *   // Or append to an existing element
   *   helper.renderGlimmer(
   *     cooked.querySelector(".some-container"),
   *     <template>I will be appended to some-container</template>
   *   );
   * }, { onlyStream: true });
   * ```
   *
   */
  renderGlimmer(targetElement, component, data) {
    // Ideally we should throw an error here, but we can't for now to prevent existing incompatible customizations from
    // crashing the app. Instead, we will log a deprecation warning while we're in the process of migrating to the new
    // Glimmer Post Stream API.
    if (!(targetElement instanceof Element)) {
      deprecated(
        "The `targetElement` parameter provided to `helper.renderGlimmer` is invalid. It must be an existing HTML element. Using a string to describe a new wrapper element is deprecated.",
        POST_STREAM_DEPRECATION_OPTIONS
      );
    }

    if (!hasInternalComponentManager(component)) {
      deprecated(
        "The `component` parameter provided to `helper.renderGlimmer` is invalid. It must be a valid Glimmer component. Using a template compiled via `ember-cli-htmlbars` is deprecated. Use the <template>...</template> syntax or replace it with a proper component.",
        POST_STREAM_DEPRECATION_OPTIONS
      );
    }

    if (!this.widget.postContentsDestroyCallbacks) {
      throw "renderGlimmer can only be used in the context of a post";
    }

    const renderGlimmer = new RenderGlimmer(
      this.widget,
      targetElement,
      component,
      data
    );
    renderGlimmer.init();
    this.widget.postContentsDestroyCallbacks.push(
      renderGlimmer.destroy.bind(renderGlimmer)
    );
    return renderGlimmer.element;
  }
}
DecoratorHelper.prototype.h = h;

export default DecoratorHelper;
