import { iconNode } from 'discourse/helpers/fa-icon';
import { addDecorator } from 'discourse/widgets/post-cooked';
import ComposerEditor from 'discourse/components/composer-editor';
import { addButton } from 'discourse/widgets/post-menu';
import { includeAttributes } from 'discourse/lib/transform-post';
import { addToolbarCallback } from 'discourse/components/d-editor';
import { addWidgetCleanCallback } from 'discourse/components/mount-widget';
import { decorateWidget } from 'discourse/widgets/widget';
import { onPageChange } from 'discourse/lib/page-tracker';

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

    this._currentUser = container.lookup('current-user:main');
  }

  getCurrentUser() {
    return this._currentUser;
  }

  /**
   * decorateCooked(callback, options)
   *
   * Used for decorating the `cooked` content of a post after it is rendered using
   * jQuery.
   *
   * `callback` will be called when it is time to decorate with a jQuery selector.
   *
   * Use `options.onlyStream` if you only want to decorate posts within a topic,
   * and not in other places like the user stream.
   *
   * For example, to add a yellow background to all posts you could do this:
   *
   * ```
   * api.decorateCooked($elem => $elem.css({ backgroundColor: 'yellow' }));
   * ```
   **/
  decorateCooked(callback, opts) {
    opts = opts || {};

    addDecorator(callback);

    if (!opts.onlyStream) {
      decorate(ComposerEditor, 'previewRefreshed', callback);
      decorate(this.container.lookupFactory('view:user-stream'), 'didInsertElement', callback);
    }
  }

  /**
   * addPosterIcon(callback)
   *
   * This function can be used to add an icon with a link that will be displayed
   * beside a poster's name. The `callback` is called with the post's user custom
   * fields and post attrions. An icon will be rendered if the callback returns
   * an object with the appropriate attributes.
   *
   * The returned object can have the following attributes:
   *
   *   icon        the font awesome icon to render
   *   emoji       an emoji icon to render
   *   className   (optional) a css class to apply to the icon
   *   url         (optional) where to link the icon
   *   title       (optional) the tooltip title for the icon on hover
   *
   * ```
   * api.addPosterIcon((cfs, attrs) => {
   *   if (cfs.customer) {
   *     return { icon: 'user', className: 'customer', title: 'customer' };
   *   }
   * });
   * ```
   **/
  addPosterIcon(cb) {
    decorateWidget('poster-name:after', dec => {
      const attrs = dec.attrs;

      const result = cb(attrs.userCustomFields || {}, attrs);
      if (result) {
        let iconBody;

        if (result.icon) {
          iconBody = iconNode(result.icon);
        } else if (result.emoji) {
          iconBody = result.emoji.split('|').map(emoji => {
            const src = Discourse.Emoji.urlFor(emoji);
            return dec.h('img', { className: 'emoji', attributes: { src } });
          });
        }

        if (result.text) {
          iconBody = [iconBody, result.text];
        }

        if (result.url) {
          iconBody = dec.h('a', { attributes: { href: result.url } }, iconBody);
        }


        return dec.h('span',
                     { className: result.className, attributes: { title: result.title } },
                     iconBody);
      }
    });
  }

  decorateWidget(name, fn) {
    decorateWidget(name, fn);
  }

  attachWidgetAction(widget, actionName, fn) {
    const widgetClass = this.container.lookupFactory(`widget:${widget}`);
    widgetClass.prototype[actionName] = fn;
  }

  includePostAttributes(...attributes) {
    includeAttributes(...attributes);
  }

  addPostMenuButton(name, callback) {
    addButton(name, callback);
  }

  onToolbarCreate(callback) {
    addToolbarCallback(callback);
  }

  cleanupStream(fn) {
    addWidgetCleanCallback('post-stream', fn);
  }

  /**
    Called whenever the "page" changes. This allows us to set up analytics
    and other tracking.

    To get notified when the page changes, you can install a hook like so:

    ```javascript
      api.onPageChange((url, title) => {
        console.log('the page changed to: ' + url + ' and title ' + title);
      });
    ```
  **/
  onPageChange(fn) {
    onPageChange(fn);
  }

}

let _pluginv01;
function getPluginApi(version) {
  if (version === "0.1") {
    if (!_pluginv01) {
      _pluginv01 = new PluginApi(version, Discourse.__container__);
    }
    return _pluginv01;
  } else {
    console.warn(`Plugin API v${version} is not supported`);
  }
}

/**
 * withPluginApi(version, apiCode, noApi)
 *
 * Helper to version our client side plugin API. Pass the version of the API that your
 * plugin is coded against. If that API is available, the `apiCodeCallback` function will
 * be called with the `PluginApi` object.
*/
export function withPluginApi(version, apiCodeCallback, opts) {
  opts = opts || {};

  const api = getPluginApi(version);
  if (api) {
    return apiCodeCallback(api);
  }
}
