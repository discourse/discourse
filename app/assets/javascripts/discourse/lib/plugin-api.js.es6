import { addDecorator } from 'discourse/widgets/post-cooked';
import ComposerEditor from 'discourse/components/composer-editor';
import { addPosterIcon } from 'discourse/widgets/poster-name';

let _decorateId = 0;
function decorate(klass, evt, cb) {
  const mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked() {
  console.warn('`decorateCooked` has been removed. Use `getPluginApi(version).decorateCooked` instead');
}

class PluginApi {
  constructor(version, container) {
    this.version = version;
    this.container = container;
  }

  /**
   * decorateCooked(callback)
   *
   * Used for decorating the `cooked` content of a post after it is rendered using
   * jQuery.
   *
   * `callback` will be called when it is time to decorate with a jQuery selector.
   *
   * For example, to add a yellow background to all posts you could do this:
   *
   * ```
   * api.decorateCooked($elem => $elem.css({ backgroundColor: 'yellow' }));
   * ```
   **/
  decorateCooked(cb) {
    addDecorator(cb);
    decorate(ComposerEditor, 'previewRefreshed', cb);
    decorate(this.container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
  }

  /**
   * addPosterIcon(callback)
   *
   * This function can be used to add an icon with a link that will be displayed
   * beside a poster's name. The `callback` is called with the post's user custom
   * fields, and will render an icon if it receives an object back.
   *
   * The returned object can have the following attributes:
   *
   *   icon        (required) the font awesome icon to render
   *   className   (optional) a css class to apply to the icon
   *   url         (optional) where to link the icon
   *   title       (optional) the tooltip title for the icon on hover
   *
   * ```
   * api.addPosterIcon(cfs => {
   *   if (cfs.customer) {
   *     return { icon: 'user', className: 'customer', title: 'customer' };
   *   }
   * });
   * ```
   **/
  addPosterIcon(cb) {
    addPosterIcon(cb);
  }
}

let _pluginv01;
export function getPluginApi(version) {
  if (version === "0.1") {
    if (!_pluginv01) {
      _pluginv01 = new PluginApi(version, Discourse.__container__);
    }
    return _pluginv01;
  } else {
    throw `Plugin API v${version} is not supported`;
  }
}
