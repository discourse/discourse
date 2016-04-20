import Connector from 'discourse/widgets/connector';
import { h } from 'virtual-dom';
import PostCooked from 'discourse/widgets/post-cooked';
import RawHtml from 'discourse/widgets/raw-html';

class DecoratorHelper {
  constructor(widget, attrs, state) {
    this.widget = widget;
    this.attrs = attrs;
    this.state = state;
    this.container = widget.container;
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
    return this.widget.findAncestorModel();
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
    return new PostCooked({ cooked });
  }

  /**
   * You can use this bridge to mount an Ember View inside the virtual
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
   * helper.connect({ templateName: 'my-handlebars-template' });
   * ```
   **/
  connect(details) {
    return new Connector(this.widget, details);
  }

}
DecoratorHelper.prototype.h = h;

export default DecoratorHelper;
