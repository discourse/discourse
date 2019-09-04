import deprecated from "discourse-common/lib/deprecated";
import { iconNode } from "discourse-common/lib/icon-library";
import { addDecorator } from "discourse/widgets/post-cooked";
import ComposerEditor from "discourse/components/composer-editor";
import DiscourseBanner from "discourse/components/discourse-banner";
import { addButton } from "discourse/widgets/post-menu";
import { includeAttributes } from "discourse/lib/transform-post";
import { registerHighlightJSLanguage } from "discourse/lib/highlight-syntax";
import { addToolbarCallback } from "discourse/components/d-editor";
import { addWidgetCleanCallback } from "discourse/components/mount-widget";
import {
  createWidget,
  reopenWidget,
  decorateWidget,
  changeSetting
} from "discourse/widgets/widget";
import { preventCloak } from "discourse/widgets/post-stream";
import { h } from "virtual-dom";
import { addPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { addPostSmallActionIcon } from "discourse/widgets/post-small-action";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery-sortable";
import { addTagsHtmlCallback } from "discourse/lib/render-tags";
import { addUserMenuGlyph } from "discourse/widgets/user-menu";
import { addPostClassesCallback } from "discourse/widgets/post";
import { addPostTransformCallback } from "discourse/widgets/post-stream";
import { attachAdditionalPanel } from "discourse/widgets/header";
import {
  registerIconRenderer,
  replaceIcon
} from "discourse-common/lib/icon-library";
import { replaceCategoryLinkRenderer } from "discourse/helpers/category-link";
import { replaceTagRenderer } from "discourse/lib/render-tag";
import { addNavItem } from "discourse/models/nav-item";
import { replaceFormatter } from "discourse/lib/utilities";
import { modifySelectKit } from "select-kit/mixins/plugin-api";
import { addGTMPageChangedCallback } from "discourse/lib/page-tracker";
import { registerCustomAvatarHelper } from "discourse/helpers/user-avatar";
import { disableNameSuppression } from "discourse/widgets/poster-name";
import { registerCustomPostMessageCallback as registerCustomPostMessageCallback1 } from "discourse/controllers/topic";
import Sharing from "discourse/lib/sharing";
import { addComposerUploadHandler } from "discourse/components/composer-editor";
import { addCategorySortCriteria } from "discourse/components/edit-category-settings";
import { queryRegistry } from "discourse/widgets/widget";

// If you add any methods to the API ensure you bump up this number
const PLUGIN_API_VERSION = "0.8.32";

class PluginApi {
  constructor(version, container) {
    this.version = version;
    this.container = container;
    this.h = h;
  }

  /**
   * Use this function to retrieve the currently logged in user within your plugin.
   * If the user is not logged in, it will be `null`.
   **/
  getCurrentUser() {
    return this._lookupContainer("current-user:main");
  }

  _lookupContainer(path) {
    if (
      !this.container ||
      this.container.isDestroying ||
      this.container.isDestroyed
    ) {
      return;
    }

    return this.container.lookup(path);
  }

  _resolveClass(resolverName, opts) {
    opts = opts || {};

    if (this.container.cache[resolverName]) {
      // eslint-disable-next-line no-console
      console.warn(
        `"${resolverName}" was already cached in the container. Changes won't be applied.`
      );
    }

    const klass = this.container.factoryFor(resolverName);
    if (!klass) {
      if (!opts.ignoreMissing) {
        // eslint-disable-next-line no-console
        console.warn(`"${resolverName}" was not found by modifyClass`);
      }
      return;
    }

    return klass;
  }

  /**
   * Allows you to overwrite or extend methods in a class.
   *
   * For example:
   *
   * ```
   * api.modifyClass('controller:composer', {
   *   actions: {
   *     newActionHere() { }
   *   }
   * });
   * ```
   **/
  modifyClass(resolverName, changes, opts) {
    const klass = this._resolveClass(resolverName, opts);
    if (klass) {
      klass.class.reopen(changes);
    }
    return klass;
  }

  /**
   * Allows you to overwrite or extend static methods in a class.
   *
   * For example:
   *
   * ```
   * api.modifyClassStatic('controller:composer', {
   *   superFinder: function() { return []; }
   * });
   * ```
   **/
  modifyClassStatic(resolverName, changes, opts) {
    const klass = this._resolveClass(resolverName, opts);
    if (klass) {
      klass.class.reopenClass(changes);
    }
    return klass;
  }

  /**
   * If you want to use custom icons in your discourse application,
   * you can register a renderer that will return an icon in the
   * format required.
   *
   * For example, the following resolver will render a smile in the place
   * of every icon on Discourse.
   *
   * api.registerIconRenderer({
   *   name: 'smile-icons',
   *
   *   // for the place in code that render a string
   *   string() {
   *     return "<svg class=\"fa d-icon d-icon-far-smile svg-icon\" aria-hidden=\"true\"><use xlink:href=\"#far-smile\"></use></svg>";
   *   },
   *
   *   // for the places in code that render virtual dom elements
   *   node() {
   *     return h("svg", {
   *          attributes: { class: "fa d-icon d-icon-far-smile", "aria-hidden": true },
   *          namespace: "http://www.w3.org/2000/svg"
   *        },[
   *          h("use", {
   *          "xlink:href": attributeHook("http://www.w3.org/1999/xlink", `#far-smile`),
   *          namespace: "http://www.w3.org/2000/svg"
   *        })]
   *     );
   *   }
   * });
   **/
  registerIconRenderer(fn) {
    registerIconRenderer(fn);
  }

  /**
   * Replace all occurrences of one icon with another without having to
   * resort to a custom IconRenderer. If you want to do something more
   * complicated than a simple replacement then create a new icon renderer.
   *
   * api.replaceIcon('d-tracking', 'smile-o');
   *
   **/
  replaceIcon(source, destination) {
    replaceIcon(source, destination);
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
   * api.decorateCooked(
   *   $elem => $elem.css({ backgroundColor: 'yellow' }),
   *   { id: 'yellow-decorator' }
   * );
   * ```
   *
   * NOTE: To avoid memory leaks, it is highly recommended to pass a unique `id` parameter.
   * You will receive a warning if you do not.
   **/
  decorateCooked(callback, opts) {
    opts = opts || {};

    addDecorator(callback);

    if (!opts.onlyStream) {
      decorate(ComposerEditor, "previewRefreshed", callback, opts.id);
      decorate(DiscourseBanner, "didInsertElement", callback, opts.id);
      decorate(
        this.container.factoryFor("component:user-stream").class,
        "didInsertElement",
        callback,
        opts.id
      );
    }
  }

  /**
   * addPosterIcon(callback)
   *
   * This function can be used to add an icon with a link that will be displayed
   * beside a poster's name. The `callback` is called with the post's user custom
   * fields and post attributes. An icon will be rendered if the callback returns
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
    const site = this._lookupContainer("site:main");
    const loc = site && site.mobileView ? "before" : "after";

    decorateWidget(`poster-name:${loc}`, dec => {
      const attrs = dec.attrs;
      const result = cb(attrs.userCustomFields || {}, attrs);

      if (result) {
        let iconBody;

        if (result.icon) {
          iconBody = iconNode(result.icon);
        } else if (result.emoji) {
          iconBody = result.emoji.split("|").map(name => {
            let widgetAttrs = { name };
            if (result.emojiTitle) widgetAttrs.title = true;
            return dec.attach("emoji", widgetAttrs);
          });
        }

        if (result.text) {
          iconBody = [iconBody, result.text];
        }

        if (result.url) {
          iconBody = dec.h("a", { attributes: { href: result.url } }, iconBody);
        }

        return dec.h(
          "span.poster-icon",
          { className: result.className, attributes: { title: result.title } },
          iconBody
        );
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
    const widgetClass =
      queryRegistry(widget) ||
      this.container.factoryFor(`widget:${widget}`).class;
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
   *    icon: 'far-eye-slash',
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
    addWidgetCleanCallback("post-stream", fn);
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
    this.onAppEvent("page:changed", data => fn(data.url, data.title));
  }

  /**
    Listen for a triggered `AppEvent` from Discourse.

    ```javascript
      api.onAppEvent('inserted-custom-html', () => {
        console.log('a custom footer was rendered');
      });
    ```
  **/
  onAppEvent(name, fn) {
    const appEvents = this._lookupContainer("app-events:main");
    appEvents && appEvents.on(name, fn);
  }

  /**
    Registers a function to generate custom avatar CSS classes
    for a particular user.

    Takes a function that will accept a user as a parameter
    and return an array of CSS classes to apply.

    ```javascript
    api.customUserAvatarClasses(user => {
      if (Ember.get(user, 'primary_group_name') === 'managers') {
        return ['managers'];
      }
    });
   **/
  customUserAvatarClasses(fn) {
    registerCustomAvatarHelper(fn);
  }

  /**
   * Allows you to disable suppression of similar username / names on posts
   * If a user has the username bob.bob and the name Bob Bob, one of the two
   * will be suppressed depending on prioritize_username_in_ux.
   * This allows you to override core behavior
   **/
  disableNameSuppressionOnPosts() {
    disableNameSuppression();
  }

  /**
   * Registers a callback that will be invoked when the server calls
   * Post#publish_change_to_clients! Please ensure your type does not
   * match acted, revised, rebaked, recovered, created, move_to_inbox
   * or archived
   *
   * callback will be called with topicController and Message
   *
   * Example:
   *
   * api.registerCustomPostMessageCallback("applied_color", (topicController, message) => {
   *   let stream = topicController.get("model.postStream");
   *   // etc
   * });
   */
  registerCustomPostMessageCallback(type, callback) {
    registerCustomPostMessageCallback1(type, callback);
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
   * register their own widgets and attach them with decorators.
   * See `createWidget` in `discourse/widgets/widget` for more info.
   **/
  createWidget(name, args) {
    return createWidget(name, args);
  }

  /**
   * Exposes the widget update ability to plugins. Updates the widget
   * registry for the given widget name to include the properties on args
   * See `reopenWidget` in `discourse/widgets/widget` from more info.
   **/

  reopenWidget(name, args) {
    return reopenWidget(name, args);
  }

  addFlagProperty() {
    deprecated(
      "addFlagProperty has been removed. Use the reviewable API instead."
    );
  }

  /**
   * Adds a panel to the header
   *
   * takes a widget name, a value to toggle on, and a function which returns the attrs for the widget
   * Example:
   * ```javascript
   * api.addHeaderPanel('widget-name', 'widgetVisible', function(attrs, state) {
   *   return { name: attrs.name, description: state.description };
   * });
   * ```
   * 'toggle' is an attribute on the state of the header widget,
   *
   * 'transformAttrs' is a function which is passed the current attrs and state of the widget,
   * and returns a hash of values to pass to attach
   *
   **/
  addHeaderPanel(name, toggle, transformAttrs) {
    attachAdditionalPanel(name, toggle, transformAttrs);
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
    const store = this._lookupContainer("service:store");
    store && store.addPluralization(thing, plural);
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
   * api.registerTopicFooterButton({
   *   key: "flag"
   *   icon: "flag"
   *   action: (context) => console.log(context.get("topic.id"))
   * });
   * ```
   **/
  registerTopicFooterButton(action) {
    registerTopicFooterButton(action);
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
  }

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
  }

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

  /**
   *
   * Adds a new item in the navigation bar.
   *
   * Example:
   *
   * addNavigationBarItem({
   *   name: "discourse",
   *   displayName: "Discourse"
   *   href: "https://www.discourse.org",
   * })
   *
   * An optional `customFilter` callback can be included to not display the
   * nav item on certain routes
   *
   * Example:
   *
   * addNavigationBarItem({
   *   name: "link-to-bugs-category",
   *   displayName: "bugs"
   *   href: "/c/bugs",
   *   customFilter: (category, args, router) => { category && category.name !== 'bug' }
   *   customHref: (category, args, router) => {  if (category && category.name) === 'not-a-bug') "/a-feature"; }
   * })
   */
  addNavigationBarItem(item) {
    if (!item["name"]) {
      // eslint-disable-next-line no-console
      console.warn(
        "A 'name' is required when adding a Navigation Bar Item.",
        item
      );
    } else {
      const customHref = item.customHref;
      if (customHref) {
        const router = this.container.lookup("service:router");
        item.customHref = function(category, args) {
          return customHref(category, args, router);
        };
      }

      const customFilter = item.customFilter;
      if (customFilter) {
        const router = this.container.lookup("service:router");
        item.customFilter = function(category, args) {
          return customFilter(category, args, router);
        };
      }

      addNavItem(item);
    }
  }

  /**
   *
   * Registers a function that will format a username when displayed. This will not
   * be applied when the username is used as an `id` or in URL strings.
   *
   * Example:
   *
   * ```
   * // display usernames in UPPER CASE
   * api.formatUsername(username => username.toUpperCase());
   *
   * ```
   *
   **/
  formatUsername(fn) {
    replaceFormatter(fn);
  }

  /**
   *
   * Access SelectKit plugin api
   *
   * Example:
   *
   * modifySelectKit("topic-footer-mobile-dropdown").appendContent(() => [{
   *   name: "discourse",
   *   id: 1
   * }])
   */
  modifySelectKit(pluginApiKey) {
    return modifySelectKit(pluginApiKey);
  }

  /**
   *
   * Registers a function that can inspect and modify the data that
   * will be sent to Google Tag Manager when a page changed event is triggered.
   *
   * Example:
   *
   * addGTMPageChangedCallback( gtmData => gtmData.locale = I18n.currentLocale() )
   *
   */
  addGTMPageChangedCallback(fn) {
    addGTMPageChangedCallback(fn);
  }

  /**
   *
   * Registers a function that can add a new sharing source
   *
   * Example:
   *
   * // read /discourse/lib/sharing.js.es6 for options
   * addSharingSource(options)
   *
   */
  addSharingSource(options) {
    Sharing.addSharingId(options.id);
    Sharing.addSource(options);
  }

  /**
   * Registers a function to handle uploads for specified file types
   * The normal uploading functionality will be bypassed if function returns
   * a falsy value.
   * This only for uploads of individual files
   *
   * Example:
   *
   * addComposerUploadHandler(["mp4", "mov"], (file, editor) => {
   *    console.log("Handling upload for", file.name);
   * })
   */
  addComposerUploadHandler(extensions, method) {
    addComposerUploadHandler(extensions, method);
  }

  /**
   * Registers a criteria that can be used as default topic order on category
   * pages.
   *
   * Example:
   *
   * categorySortCriteria("votes");
   */
  addCategorySortCriteria(criteria) {
    addCategorySortCriteria(criteria);
  }

  /**
   * Registers a renderer that overrides the display of category links.
   *
   * Example:
   *
   * function testReplaceRenderer(category, opts) {
   *   return "Hello World";
   * }
   * api.replaceCategoryLinkRenderer(categoryIconsRenderer);
   **/
  replaceCategoryLinkRenderer(fn) {
    replaceCategoryLinkRenderer(fn);
  }

  /**
   * Registers a renderer that overrides the display of a tag.
   *
   * Example:
   *
   * function testTagRenderer(tag, params) {
   *   const visibleName = Handlebars.Utils.escapeExpression(tag);
   *   return `testing: ${visibleName}`;
   * }
   * api.replaceTagRenderer(testTagRenderer);
   **/
  replaceTagRenderer(fn) {
    replaceTagRenderer(fn);
  }

  /**
   * Registers custom languages for use with HighlightJS.
   *
   * See https://highlightjs.readthedocs.io/en/latest/language-guide.html
   * for instructions on how to define a new language for HighlightJS.
   * Build minified language file by running "node tools/build.js -t cdn" in the HighlightJS repo
   * and use the minified output as the registering function.
   *
   * Example:
   *
   * let aLang = function(e){return{cI:!1,c:[{bK:"GET HEAD PUT POST DELETE PATCH",e:"$",c:[{cN:"title",b:"/?.+"}]},{b:"^{$",e:"^}$",sL:"json"}]}}
   * api.registerHighlightJSLanguage("kibana", aLang);
   **/
  registerHighlightJSLanguage(name, fn) {
    registerHighlightJSLanguage(name, fn);
  }
}

let _pluginv01;

// from http://stackoverflow.com/questions/6832596/how-to-compare-software-version-number-using-js-only-number
function cmpVersions(a, b) {
  var i, diff;
  var regExStrip0 = /(\.0+)+$/;
  var segmentsA = a.replace(regExStrip0, "").split(".");
  var segmentsB = b.replace(regExStrip0, "").split(".");
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
  if (cmpVersions(version, PLUGIN_API_VERSION) <= 0) {
    if (!_pluginv01) {
      _pluginv01 = new PluginApi(version, Discourse.__container__);
    }

    // We are recycling the compatible object, but let's update to the higher version
    if (_pluginv01.version < version) {
      _pluginv01.version = version;
    }
    return _pluginv01;
  } else {
    // eslint-disable-next-line no-console
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
let _decorated = new WeakMap();

function decorate(klass, evt, cb, id) {
  if (!id) {
    // eslint-disable-next-line no-console
    console.warn(
      "`decorateCooked` should be supplied with an `id` option to avoid memory leaks."
    );
  } else {
    if (!_decorated.has(klass)) {
      _decorated.set(klass, new Set());
    }
    id = `${id}:${evt}`;
    let set = _decorated.get(klass);
    if (set.has(id)) {
      return;
    }
    set.add(id);
  }

  const mixin = {};
  mixin["_decorate_" + _decorateId++] = function($elem) {
    $elem = $elem || $(this.element);
    if ($elem) {
      cb($elem);
    }
  }.on(evt);
  klass.reopen(mixin);
}

export function resetPluginApi() {
  _pluginv01 = null;
}
