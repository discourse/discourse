import { iconNode } from 'discourse/helpers/fa-icon-node';
import { addDecorator } from 'discourse/widgets/post-cooked';
import ComposerEditor from 'discourse/components/composer-editor';
import { addButton } from 'discourse/widgets/post-menu';
import { includeAttributes } from 'discourse/lib/transform-post';
import { addToolbarCallback } from 'discourse/components/d-editor';
import { addWidgetCleanCallback } from 'discourse/components/mount-widget';
import { createWidget, reopenWidget, decorateWidget, changeSetting } from 'discourse/widgets/widget';
import { onPageChange } from 'discourse/lib/page-tracker';
import { preventCloak } from 'discourse/widgets/post-stream';
import { h } from 'virtual-dom';
import { addFlagProperty } from 'discourse/components/site-header';
import { addPopupMenuOptionsCallback } from 'discourse/controllers/composer';
import { extraConnectorClass } from 'discourse/lib/plugin-connectors';
import { addPostSmallActionIcon } from 'discourse/widgets/post-small-action';
import { addDiscoveryQueryParam } from 'discourse/controllers/discovery-sortable';
import { addTagsHtmlCallback } from 'discourse/lib/render-tags';
import { addUserMenuGlyph } from 'discourse/widgets/user-menu';
import { addPostClassesCallback } from 'discourse/widgets/post';
import { addPostTransformCallback } from 'discourse/widgets/post-stream';

// If you add any methods to the API ensure you bump up this number
const PLUGIN_API_VERSION = '0.8.5';

class PluginApi {
  constructor(version, container) {
    this.version = version;
    this.container = container;
    this._currentUser = container.lookup('current-user:main');
    this.h = h;
  }

  /**
   * Use this function to retrieve the currently logged in user within your plugin.
   * If the user is not logged in, it will be `null`.
  **/
  getCurrentUser() {
    return this._currentUser;
  }

  /**
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
      decorate(this.container.lookupFactory('component:user-stream'), 'didInsertElement', callback);
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
    const site = this.container.lookup('site:main');
    const loc = site && site.mobileView ? 'before' : 'after';

    decorateWidget(`poster-name:${loc}`, dec => {
      const attrs = dec.attrs;
      const result = cb(attrs.userCustomFields || {}, attrs);

      if (result) {
        let iconBody;

        if (result.icon) {
          iconBody = iconNode(result.icon);
        } else if (result.emoji) {
          iconBody = result.emoji.split('|').map(name => {
            let widgetAttrs = { name };
            if (result.emojiTitle) widgetAttrs.title = true;
            return dec.attach('emoji', widgetAttrs);
          });
        }

        if (result.text) {
          iconBody = [iconBody, result.text];
        }

        if (result.url) {
          iconBody = dec.h('a', { attributes: { href: result.url } }, iconBody);
        }


        return dec.h('span.poster-icon',
                     { className: result.className, attributes: { title: result.title } },
                     iconBody);
      }
    });
  }

  /**
   * The main interface for extending widgets with additional HTML.
   *
   * The `name` you pass it should be the name of the widget and a type
   * for the decorator. All widgets support `before` and `after` types.
   *
   * Example:
   *
   * ```
   * api.decorateWidget('post:after', () => {
   *   return "I am displayed after every post!";
   * });
   * ```
   *
   * Your decorator will be called with an instance of a `DecoratorHelper`
   * object, which provides methods you can use to build more interesting
   * formatting.
   *
   * ```
   * api.decorateWidget('post:after', helper => {
   *   return helper.h('p.fancy', `I'm an HTML paragraph on post with id ${helper.attrs.id}`);
   * });
   *
   * (View the source for `DecoratorHelper` for more helper methods you
   * can use in your plugin decorators.)
   *
   **/
  decorateWidget(name, fn) {
    decorateWidget(name, fn);
  }

  /**
   * Adds a new action to a widget that already exists. You can use this to
   * add additional functionality from your plugin.
   *
   * Example:
   *
   * ```
   * api.attachWidgetAction('post', 'annoyMe', () => {
   *  alert('ANNOYED!');
   * });
   * ```
   **/
  attachWidgetAction(widget, actionName, fn) {
    const widgetClass = this.container.lookupFactory(`widget:${widget}`);
    widgetClass.prototype[actionName] = fn;
  }

  /**
   * Add more attributes to the Post's `attrs` object passed through to widgets.
   * You'll need to do this if you've added attributes to the serializer for a
   * Post and want to use them when you're rendering.
   *
   * Example:
   *
   * ```
   * // attrs.poster_age and attrs.poster_height will be present
   * api.includePostAttributes('poster_age', 'poster_height');
   * ```
   *
   **/
  includePostAttributes(...attributes) {
    includeAttributes(...attributes);
  }

  /**
   * Add a new button below a post with your plugin.
   *
   * The `callback` function will be called whenever the post menu is rendered,
   * and if you return an object with the button details it will be rendered.
   *
   * Example:
   *
   * ```
   * api.addPostMenuButton('coffee', () => {
   *   return {
   *     action: 'drinkCoffee',
   *     icon: 'coffee',
   *     className: 'hot-coffee',
   *     title: 'coffee.title',
   *     position: 'first'  // can be `first`, `last` or `second-last-hidden`
   *   };
   * });
   **/
  addPostMenuButton(name, callback) {
    addButton(name, callback);
  }

  /**
   * A hook that is called when the editor toolbar is created. You can
   * use this to add custom editor buttons.
   *
   * Example:
   *
   * ```
   * api.onToolbarCreate(toolbar => {
   *   toolbar.addButton({
   *     id: 'pop-text',
   *     group: 'extras',
   *     icon: 'bolt',
   *     action: 'makeItPop',
   *     title: 'pop_format.title'
   *   });
   * });
   **/
  onToolbarCreate(callback) {
    addToolbarCallback(callback);
  }

  /**
   * Add a new button in the options popup menu.
   *
   * Example:
   *
   * ```
   * api.addToolbarPopupMenuOptionsCallback(() => {
   *  return {
   *    action: 'toggleWhisper',
   *    icon: 'eye-slash',
   *    label: 'composer.toggle_whisper',
   *    condition: "canWhisper"
   *  };
   * });
   * ```
  **/
  addToolbarPopupMenuOptionsCallback(callback) {
    addPopupMenuOptionsCallback(callback);
  }

  /**
   * A hook that is called when the post stream is removed from the DOM.
   * This advanced hook should be used if you end up wiring up any
   * events that need to be torn down when the user leaves the topic
   * page.
   **/
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

  /**
   * Changes a setting associated with a widget. For example, if
   * you wanted small avatars in the post stream:
   *
   * ```javascript
   * api.changeWidgetSetting('post-avatar', 'size', 'small');
   * ```
   *
   **/
  changeWidgetSetting(widgetName, settingName, newValue) {
    changeSetting(widgetName, settingName, newValue);
  }

  /**
   * Prevents an element in the post stream from being cloaked.
   * This is useful if you are using a plugin such as youtube
   * and don't want the video removed once it has begun
   * playing.
   *
   * ```javascript
   * api.preventCloak(1234);
   * ```
   **/
  preventCloak(postId) {
    preventCloak(postId);
  }

  /**
   * Exposes the widget creating ability to plugins. Plugins can
   * register their own plugins and attach them with decorators.
   * See `createWidget` in `discourse/widgets/widget` for more info.
   **/
  createWidget(name, args) {
    return createWidget(name, args);
  }

  /**
   * Exposes the widget update ability to plugins. Updates the widget
   * registry for the given widget name to include the properties on args
   * See `reopenWidget` in `discourse/widgets/widget` from more ifo.
  **/

  reopenWidget(name, args) {
    return reopenWidget(name, args);
  }

  /**
   * Adds a property that can be summed for calculating the flag counter
   **/
  addFlagProperty(property) {
    return addFlagProperty(property);
  }

  /**
   * Adds a pluralization to the store
   *
   * Example:
   *
   * ```javascript
   * api.addStorePluralization('mouse', 'mice');
   * ```
   *
   * ```javascript
   * this.store.find('mouse');
   * ```
   * will issue a request to `/mice.json`
   **/
  addStorePluralization(thing, plural) {
    this.container.lookup("store:main").addPluralization(thing, plural);
  }

  /**
   * Register a Connector class for a particular outlet and connector.
   *
   * For example, if the outlet is `user-profile-primary` and your connector
   * template is called `my-connector.hbs`:
   *
   * ```javascript
   * api.registerConnectorClass('user-profile-primary', 'my-connector', {
   *   shouldRender(args, component) {
   *     return component.siteSettings.my_plugin_enabled;
   *   }
   * });
   * ```
   *
   * For more information on connector classes, see:
   * https://meta.discourse.org/t/important-changes-to-plugin-outlets-for-ember-2-10/54136
   **/
  registerConnectorClass(outletName, connectorName, klass) {
    extraConnectorClass(`${outletName}/${connectorName}`, klass);
  }

  /**
   * Register a small icon to be used for custom small post actions
   *
   * ```javascript
   * api.registerPostSmallActionIcon('assign-to', 'user-add');
   * ```
   **/
  addPostSmallActionIcon(key, icon) {
    addPostSmallActionIcon(key, icon);
  }

  /**
   * Register an additional query param with topic discovery,
   * this allows for filters on the topic list
   *
   **/
  addDiscoveryQueryParam(param, options) {
    addDiscoveryQueryParam(param, options);
  }

  /**
   * Register a callback to be called every time tags render
   * highest priority callbacks are called first
   * example:
   *
   * callback = function(topic, params) {
   *    if (topic.get("created_at") < "2000-00-01") {
   *      return "<span class='discourse-tag'>ANCIENT</span>"
   *    }
   * }
   *
   * api.addTagsHtmlCallback(callback, {priority: 100});
   *
   **/
  addTagsHtmlCallback(callback, options) {
    addTagsHtmlCallback(callback, options);
  };

  /**
   * Adds a glyph to user menu after bookmarks
   * WARNING: there is limited space there
   *
   * example:
   *
   * api.addUserMenuGlyph({
   *    label: 'awesome.label',
   *    className: 'my-class',
   *    icon: 'my-icon',
   *    href: `/some/path`
   * });
   *
   */
  addUserMenuGlyph(glyph) {
    addUserMenuGlyph(glyph);
  };

  /**
   * Adds a callback to be called before rendering any post that
   * that returns custom classes to add to the post
   *
   * Example:
   *
   * addPostClassesCallback((atts) => {if (atts.post_number == 1) return ["first"];})
   **/
  addPostClassesCallback(callback) {
    addPostClassesCallback(callback);
  }

  /**
   *
   * Adds a callback to be executed on the "transformed" post that is passed to the post
   * widget.
   *
   * This allows you to apply transformations on the actual post that is about to be rendered.
   *
   * Example:
   *
   * addPostTransformCallback((t)=>{
   *  // post number 7 is overrated, don't show it ever
   *  if (t.post_number === 7) { t.cooked = ""; }
   * })
   */
  addPostTransformCallback(callback) {
    addPostTransformCallback(callback);
  }
}

let _pluginv01;


// from http://stackoverflow.com/questions/6832596/how-to-compare-software-version-number-using-js-only-number
function cmpVersions (a, b) {
    var i, diff;
    var regExStrip0 = /(\.0+)+$/;
    var segmentsA = a.replace(regExStrip0, '').split('.');
    var segmentsB = b.replace(regExStrip0, '').split('.');
    var l = Math.min(segmentsA.length, segmentsB.length);

    for (i = 0; i < l; i++) {
        diff = parseInt(segmentsA[i], 10) - parseInt(segmentsB[i], 10);
        if (diff) {
            return diff;
        }
    }
    return segmentsA.length - segmentsB.length;
}



function getPluginApi(version) {
  version = version.toString();
  if (cmpVersions(version,PLUGIN_API_VERSION) <= 0) {
    if (!_pluginv01) {
      _pluginv01 = new PluginApi(version, Discourse.__container__);
    }

    // We are recycling the compatible object, but let's update to the higher version
    if (_pluginv01.version < version) {
      _pluginv01.version = version;
    }
    return _pluginv01;
  } else {
    console.warn(`Plugin API v${version} is not supported`);
  }
}

/**
 * withPluginApi(version, apiCodeCallback, opts)
 *
 * Helper to version our client side plugin API. Pass the version of the API that your
 * plugin is coded against. If that API is available, the `apiCodeCallback` function will
 * be called with the `PluginApi` object.
*/
export function withPluginApi(version, apiCodeCallback, opts) {
  opts = opts || {};

  const api = getPluginApi(version);
  if (api) {
    return apiCodeCallback(api, opts);
  }
}

let _decorateId = 0;
function decorate(klass, evt, cb) {
  const mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function resetPluginApi() {
  _pluginv01 = null;
}

export function decorateCooked() {
  console.warn('`decorateCooked` has been removed. Use `getPluginApi(version).decorateCooked` instead');
}
