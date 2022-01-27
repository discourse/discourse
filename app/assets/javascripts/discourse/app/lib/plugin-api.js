import ComposerEditor, {
  addComposerUploadHandler,
  addComposerUploadMarkdownResolver,
  addComposerUploadPreProcessor,
} from "discourse/components/composer-editor";
import {
  addButton,
  apiExtraButtons,
  removeButton,
} from "discourse/widgets/post-menu";
import {
  addExtraIconRenderer,
  replaceCategoryLinkRenderer,
} from "discourse/helpers/category-link";
import {
  addPostTransformCallback,
  preventCloak,
} from "discourse/widgets/post-stream";
import {
  addSaveableUserField,
  addSaveableUserOptionField,
} from "discourse/models/user";
import {
  addToHeaderIcons,
  attachAdditionalPanel,
} from "discourse/widgets/header";
import {
  changeSetting,
  createWidget,
  decorateWidget,
  queryRegistry,
  reopenWidget,
} from "discourse/widgets/widget";
import {
  iconNode,
  registerIconRenderer,
  replaceIcon,
} from "discourse-common/lib/icon-library";
import Composer, {
  registerCustomizationCallback,
} from "discourse/models/composer";
import DiscourseBanner from "discourse/components/discourse-banner";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import Sharing from "discourse/lib/sharing";
import { addAdvancedSearchOptions } from "discourse/components/search-advanced-options";
import { addCardClickListenerSelector } from "discourse/mixins/card-contents-base";
import { addCategorySortCriteria } from "discourse/components/edit-category-settings";
import { addDecorator } from "discourse/widgets/post-cooked";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery-sortable";
import { addFeaturedLinkMetaDecorator } from "discourse/lib/render-topic-featured-link";
import { addGTMPageChangedCallback } from "discourse/lib/page-tracker";
import { addGlobalNotice } from "discourse/components/global-notice";
import { addNavItem } from "discourse/models/nav-item";
import { addPluginDocumentTitleCounter } from "discourse/components/d-document";
import { addPluginOutletDecorator } from "discourse/components/plugin-connector";
import { addPluginReviewableParam } from "discourse/components/reviewable-item";
import { addPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { addPostClassesCallback } from "discourse/widgets/post";
import {
  addGroupPostSmallActionCode,
  addPostSmallActionIcon,
} from "discourse/widgets/post-small-action";
import { addQuickAccessProfileItem } from "discourse/widgets/quick-access-profile";
import { addTagsHtmlCallback } from "discourse/lib/render-tags";
import { addToolbarCallback } from "discourse/components/d-editor";
import { addTopicParticipantClassesCallback } from "discourse/widgets/topic-map";
import { addTopicTitleDecorator } from "discourse/components/topic-title";
import { addUserMenuGlyph } from "discourse/widgets/user-menu";
import { addUsernameSelectorDecorator } from "discourse/helpers/decorate-username-selector";
import { addWidgetCleanCallback } from "discourse/components/mount-widget";
import deprecated from "discourse-common/lib/deprecated";
import { disableNameSuppression } from "discourse/widgets/poster-name";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { getOwner } from "discourse-common/lib/get-owner";
import { h } from "virtual-dom";
import { includeAttributes } from "discourse/lib/transform-post";
import { modifySelectKit } from "select-kit/mixins/plugin-api";
import { on } from "@ember/object/evented";
import { registerCustomAvatarHelper } from "discourse/helpers/user-avatar";
import { registerCustomPostMessageCallback as registerCustomPostMessageCallback1 } from "discourse/controllers/topic";
import { registerHighlightJSLanguage } from "discourse/lib/highlight-syntax";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import { registerTopicFooterDropdown } from "discourse/lib/register-topic-footer-dropdown";
import { registerDesktopNotificationHandler } from "discourse/lib/desktop-notifications";
import { replaceFormatter } from "discourse/lib/utilities";
import { replaceTagRenderer } from "discourse/lib/render-tag";
import { setNewCategoryDefaultColors } from "discourse/routes/new-category";
import { addSearchResultsCallback } from "discourse/lib/search";
import {
  addQuickSearchRandomTip,
  addSearchSuggestion,
} from "discourse/widgets/search-menu-results";
import { CUSTOM_USER_SEARCH_OPTIONS } from "select-kit/components/user-chooser";
import { downloadCalendar } from "discourse/lib/download-calendar";

// If you add any methods to the API ensure you bump up the version number
// based on Semantic Versioning 2.0.0. Please update the changelog at
// docs/CHANGELOG-JAVASCRIPT-PLUGIN-API.md whenever you change the version
// using the format described at https://keepachangelog.com/en/1.0.0/.
const PLUGIN_API_VERSION = "1.1.0";

// This helper prevents us from applying the same `modifyClass` over and over in test mode.
function canModify(klass, type, resolverName, changes) {
  if (!changes.pluginId) {
    // eslint-disable-next-line no-console
    console.warn(
      "To prevent errors in tests, add a `pluginId` key to your `modifyClass` call. This will ensure the modification is only applied once."
    );
    return true;
  }

  let key = "_" + type + "/" + changes.pluginId + "/" + resolverName;
  if (klass.class[key]) {
    return false;
  } else {
    klass.class[key] = 1;
    return true;
  }
}

function wrapWithErrorHandler(func, messageKey) {
  return function () {
    try {
      return func.call(this, ...arguments);
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: { messageKey, error },
        })
      );
      return;
    }
  };
}

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
   * You should add a `pluginId` property to identify your plugin
   * to help Discourse reload classes properly.
   *
   * For example:
   *
   * ```
   * api.modifyClass('controller:composer', {
   *   pluginId: 'my-plugin',
   *   actions: {
   *     newActionHere() { }
   *   }
   * });
   * ```
   **/
  modifyClass(resolverName, changes, opts) {
    const klass = this._resolveClass(resolverName, opts);
    if (!klass) {
      return;
    }

    if (canModify(klass, "member", resolverName, changes)) {
      delete changes.pluginId;
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
   *   superFinder() { return []; }
   * });
   * ```
   **/
  modifyClassStatic(resolverName, changes, opts) {
    const klass = this._resolveClass(resolverName, opts);
    if (!klass) {
      return;
    }

    if (canModify(klass, "static", resolverName, changes)) {
      delete changes.pluginId;
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
   *     return "<svg class=\"fa d-icon d-icon-far-smile svg-icon\" aria-hidden=\"true\"><use href=\"#far-smile\"></use></svg>";
   *   },
   *
   *   // for the places in code that render virtual dom elements
   *   node() {
   *     return h("svg", {
   *          attributes: { class: "fa d-icon d-icon-far-smile", "aria-hidden": true },
   *          namespace: "http://www.w3.org/2000/svg"
   *        },[
   *          h("use", {
   *          "href": attributeHook("http://www.w3.org/1999/xlink", `#far-smile`),
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
   * Method for decorating the `cooked` content of a post using JQuery
   *
   * You should use decorateCookedElement instead, which works without JQuery
   *
   * This method will be deprecated in future
   **/
  decorateCooked(callback, opts) {
    this.decorateCookedElement(
      (element, decoratorHelper) => callback($(element), decoratorHelper),
      opts
    );
  }

  /**
   * Used for decorating the `cooked` content of a post after it is rendered
   *
   * `callback` will be called when it is time to decorate with an DOM node.
   *
   * Use `options.onlyStream` if you only want to decorate posts within a topic,
   * and not in other places like the user stream.
   *
   * Decoration normally happens in a detached DOM. Use `options.afterAdopt`
   * to decorate html content after it is adopted by the main `document`.
   *
   * For example, to add a yellow background to all posts you could do this:
   *
   * ```
   * api.decorateCookedElement(
   *   elem => { elem.style.backgroundColor = 'yellow' },
   *   { id: 'yellow-decorator' }
   * );
   * ```
   *
   * NOTE: To avoid memory leaks, it is highly recommended to pass a unique `id` parameter.
   * You will receive a warning if you do not.
   **/
  decorateCookedElement(callback, opts) {
    opts = opts || {};

    callback = wrapWithErrorHandler(callback, "broken_decorator_alert");

    addDecorator(callback, { afterAdopt: !!opts.afterAdopt });

    if (!opts.onlyStream) {
      decorate(ComposerEditor, "previewRefreshed", callback, opts.id);
      decorate(DiscourseBanner, "didInsertElement", callback, opts.id);
      ["didInsertElement", "user-stream:new-item-inserted"].forEach((event) => {
        const klass = this.container.factoryFor("component:user-stream").class;
        decorate(klass, event, callback, opts.id);
      });
    }
  }

  /**
   * See KeyboardShortcuts.addShortcut documentation.
   **/
  addKeyboardShortcut(shortcut, callback, opts = {}) {
    KeyboardShortcuts.addShortcut(shortcut, callback, opts);
  }

  /**
   * addPosterIcon(callback)
   *
   * This function is an alias of addPosterIcons, which the latter has the ability
   * to add multiple icons at once. Please refer to `addPosterIcons` for usage examples.
   **/
  addPosterIcon(cb) {
    this.addPosterIcons(cb);
  }

  /**
   * addPosterIcons(callback)
   *
   * This function can be used to add one, or multiple icons, with a link that will
   * be displayed beside a poster's name. The `callback` is called with the post's
   * user custom fields and post attributes. One or multiple icons may be rendered
   * when the callback returns an array of objects with the appropriate attributes.
   *
   * The returned object(s) each can have the following attributes:
   *
   *   icon        the font awesome icon to render
   *   emoji       an emoji icon to render
   *   className   (optional) a css class to apply to the icon
   *   url         (optional) where to link the icon
   *   title       (optional) the tooltip title for the icon on hover
   *   text        (optional) text to display alongside the emoji or icon
   *
   * ```
   * api.addPosterIcons((cfs, attrs) => {
   *   if (cfs.customer) {
   *     return { icon: 'user', className: 'customer', title: 'customer' };
   *   }
   * });
   * ```
   * or
   * * ```
   * api.addPosterIcons((cfs, attrs) => {
   *   return attrs.customers.map(({name}) => {
   *     icon: 'user', className: 'customer', title: name
   *   })
   * });
   * ```
   **/
  addPosterIcons(cb) {
    const site = this._lookupContainer("site:main");
    const loc = site && site.mobileView ? "before" : "after";

    decorateWidget(`poster-name:${loc}`, (dec) => {
      const attrs = dec.attrs;
      let results = cb(attrs.userCustomFields || {}, attrs);

      if (results) {
        if (!Array.isArray(results)) {
          results = [results];
        }

        return results.map((result) => {
          let iconBody;

          if (result.icon) {
            iconBody = iconNode(result.icon);
          } else if (result.emoji) {
            iconBody = result.emoji.split("|").map((name) => {
              let widgetAttrs = { name };
              if (result.emojiTitle) {
                widgetAttrs.title = true;
              }
              return dec.attach("emoji", widgetAttrs);
            });
          }

          if (result.text) {
            iconBody = [iconBody, result.text];
          }

          if (result.url) {
            iconBody = dec.h(
              "a",
              { attributes: { href: result.url } },
              iconBody
            );
          }

          return dec.h(
            "span.poster-icon",
            {
              className: result.className,
              attributes: { title: result.title },
            },
            iconBody
          );
        });
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
   * ```
   **/
  addPostMenuButton(name, callback) {
    apiExtraButtons[name] = callback;
    addButton(name, callback);
  }

  /**
   * Remove existing button below a post with your plugin.
   *
   * Example:
   *
   * ```
   * api.removePostMenuButton('like');
   * ```
   *
   * ```
   * api.removePostMenuButton('like', (attrs, state, siteSettings, settings, currentUser) => {
   *   if (attrs.post_number === 1) {
   *     return true;
   *   }
   * });
   * ```
   **/
  removePostMenuButton(name, callback) {
    removeButton(name, callback);
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
    this.onAppEvent("page:changed", (data) => fn(data.url, data.title));
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
    const appEvents = this._lookupContainer("service:app-events");
    appEvents && appEvents.on(name, fn);
  }

  /**
   Registers a function to generate custom avatar CSS classes
   for a particular user.

   Takes a function that will accept a user as a parameter
   and return an array of CSS classes to apply.

   ```javascript
   api.customUserAvatarClasses(user => {
      if (get(user, 'primary_group_name') === 'managers') {
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
   * Register a button to display at the bottom of a topic
   *
   * ```javascript
   * api.registerTopicFooterButton({
   *   id: "flag",
   *   icon: "flag",
   *   action(context) { console.log(context.get("topic.id")) },
   * });
   * ```
   **/
  registerTopicFooterButton(buttonOptions) {
    registerTopicFooterButton(buttonOptions);
  }

  /**
   * Register a dropdown to display at the bottom of a topic, desktop only
   *
   * ```javascript
   * api.registerTopicFooterDropdown({
   *   id: "my-button",
   *   content() { return [{id: 1, name: "foo"}] },
   *   action(itemId) { console.log(itemId) },
   * });
   * ```
   **/
  registerTopicFooterDropdown(dropdownOptions) {
    registerTopicFooterDropdown(dropdownOptions);
  }

  /**
   * Register a desktop notificaiton handler
   *
   * ```javascript
   * api.registerDesktopNotificationHandler((data, siteSettings, user) => {
   *   // Do something!
   * });
   * ```
   **/
  registerDesktopNotificationHandler(handler) {
    registerDesktopNotificationHandler(handler);
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
   * Register a small action code to be used for small post actions containing a link to a group
   *
   * ```javascript
   * api.addGroupPostSmallActionCode('group_assigned');
   * ```
   **/
  addGroupPostSmallActionCode(actionCode) {
    addGroupPostSmallActionCode(actionCode);
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
   *    title: 'awesome.label',
   *    className: 'my-class',
   *    icon: 'my-icon',
   *    data: { url: `/some/path` },
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
   * addPostClassesCallback((attrs) => {if (attrs.post_number == 1) return ["first"];})
   **/
  addPostClassesCallback(callback) {
    addPostClassesCallback(callback);
  }

  /**
   * Adds a callback to be called before rendering a topic participant that
   * that returns custom classes to add to the participant element
   *
   * Example:
   *
   * addTopicParticipantClassesCallback((attrs) => {if (attrs.primary_group_name == "moderator") return ["important-participant"];})
   **/
  addTopicParticipantClassesCallback(callback) {
    addTopicParticipantClassesCallback(callback);
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
   * Adds a new item in the navigation bar. Returns the NavItem object created.
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
   * An optional `init` callback can be included to run custom code on menu
   * init
   *
   * Example:
   *
   * addNavigationBarItem({
   *   name: "link-to-bugs-category",
   *   displayName: "bugs"
   *   href: "/c/bugs",
   *   init: (navItem, category) => { if (category) { navItem.set("category", category)  } }
   *   customFilter: (category, args, router) => { return category && category.name !== 'bug' }
   *   customHref: (category, args, router) => {  if (category && category.name) === 'not-a-bug') return "/a-feature"; },
   *   before: "top",
   *   forceActive(category, args, router) => router.currentURL === "/a/b/c/d";
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
        item.customHref = function (category, args) {
          return customHref(category, args, router);
        };
      }

      const customFilter = item.customFilter;
      if (customFilter) {
        const router = this.container.lookup("service:router");
        item.customFilter = function (category, args) {
          return customFilter(category, args, router);
        };
      }

      const forceActive = item.forceActive;
      if (forceActive) {
        const router = this.container.lookup("service:router");
        item.forceActive = function (category, args) {
          return forceActive(category, args, router);
        };
      }

      const init = item.init;
      if (init) {
        const router = this.container.lookup("service:router");
        item.init = function (navItem, category, args) {
          init(navItem, category, args, router);
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
   * api.modifySelectKit("topic-footer-mobile-dropdown").appendContent(() => [{
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
   * api.addGTMPageChangedCallback( gtmData => gtmData.locale = I18n.currentLocale() )
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
   * // read discourse/lib/sharing for options
   * api.addSharingSource(options)
   *
   */
  addSharingSource(options) {
    Sharing.addSharingId(options.id);
    Sharing.addSource(options);
  }

  /**
   * Registers a function to handle uploads for specified file types.
   * The normal uploading functionality will be bypassed if function returns
   * a falsy value.
   *
   * Example:
   *
   * api.addComposerUploadHandler(["mp4", "mov"], (files, editor) => {
   *   files.forEach((file) => {
   *     console.log("Handling upload for", file.name);
   *   });
   * })
   */
  addComposerUploadHandler(extensions, method) {
    addComposerUploadHandler(extensions, method);
  }

  /**
   * Registers a pre-processor for file uploads in the form
   * of an Uppy preprocessor plugin.
   *
   * See https://uppy.io/docs/writing-plugins/ for the Uppy
   * documentation, but other examples of preprocessors in core
   * can be found in UppyMediaOptimization and UppyChecksum.
   *
   * Useful for transforming to-be uploaded files client-side.
   *
   * Example:
   *
   * api.addComposerUploadPreProcessor(UppyMediaOptimization, ({ composerModel, composerElement, capabilities, isMobileDevice }) => {
   *   return {
   *     composerModel,
   *     composerElement,
   *     capabilities,
   *     isMobileDevice,
   *     someOption: true,
   *     someFn: () => {},
   *   };
   * });
   *
   * @param {BasePlugin} pluginClass The uppy plugin class to use for the preprocessor.
   * @param {Function} optionsResolverFn This function should return an object which is passed into the constructor
   *                                     of the uppy plugin as the options argument. The object passed to the function
   *                                     contains references to the composer model, element, the capabilities of the
   *                                     browser, and isMobileDevice.
   */
  addComposerUploadPreProcessor(pluginClass, optionsResolverFn) {
    addComposerUploadPreProcessor(pluginClass, optionsResolverFn);
  }

  /**
   * Registers a function to generate Markdown after a file has been uploaded.
   *
   * Example:
   *
   * api.addComposerUploadMarkdownResolver(upload => {
   *   return `_uploaded ${upload.original_filename}_`;
   * })
   */
  addComposerUploadMarkdownResolver(resolver) {
    addComposerUploadMarkdownResolver(resolver);
  }

  /**
   * Registers a function to decorate each autocomplete usernames.
   *
   * Example:
   *
   * api.addUsernameSelectorDecorator(username => {
   *   return `<span class="status">[is_away]</class>`;
   * })
   */
  addUsernameSelectorDecorator(decorator) {
    addUsernameSelectorDecorator(decorator);
  }

  /**
   * Registers a "beforeSave" function on the composer. This allows you to
   * implement custom logic that will happen before the user makes a post.
   *
   * Example:
   *
   * api.composerBeforeSave(() => {
   *   console.log("Before saving, do something!");
   * })
   */
  composerBeforeSave(method) {
    Composer.reopen({ beforeSave: method });
  }

  /**
   * Adds a field to topic edit serializer
   *
   * Example:
   *
   * api.serializeToTopic('key_set_in_model', 'field_name_in_payload');
   *
   * to keep both of them same
   * api.serializeToTopic('field_name');
   *
   */
  serializeToTopic(fieldName, property) {
    Composer.serializeToTopic(fieldName, property);
  }

  /**
   * Adds a field to draft serializer
   *
   * Example:
   *
   * api.serializeToDraft('key_set_in_model', 'field_name_in_payload');
   *
   * to keep both of them same
   * api.serializeToDraft('field_name');
   *
   */
  serializeToDraft(fieldName, property) {
    Composer.serializeToDraft(fieldName, property);
  }

  /**
   * Adds a field to composer create serializer
   *
   * Example:
   *
   * api.serializeOnCreate('key_set_in_model', 'field_name_in_payload');
   *
   * to keep both of them same
   * api.serializeOnCreate('field_name');
   *
   */
  serializeOnCreate(fieldName, property) {
    Composer.serializeOnCreate(fieldName, property);
  }

  /**
   * Adds a field to composer update serializer
   *
   * Example:
   *
   * api.serializeOnUpdate('key_set_in_model', 'field_name_in_payload');
   *
   * to keep both of them same
   * api.serializeOnUpdate('field_name');
   *
   */
  serializeOnUpdate(fieldName, property) {
    Composer.serializeOnUpdate(fieldName, property);
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
   * Card contents mixin will add a listener to elements matching this selector
   * that will open card contents when a mention of div with the correct data attribute
   * is clicked
   */
  addCardClickListenerSelector(selector) {
    addCardClickListenerSelector(selector);
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
   *   const visibleName = escapeExpression(tag);
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

  /**
   * Adds global notices to display.
   *
   * Example:
   *
   * api.addGlobalNotice("text", "foo", { html: "<p>bar</p>" })
   *
   **/
  addGlobalNotice(text, id, options) {
    addGlobalNotice(text, id, options);
  }

  /**
   * Used for modifying the document title count. The core count is unread notifications, and
   * the returned value from calling the passed in function will be added to this number.
   *
   * For example, to add a count
   * api.addDocumentTitleCounter(() => {
   *   return currentUser.somePluginValue;
   * })
   **/
  addDocumentTitleCounter(counterFunction) {
    addPluginDocumentTitleCounter(counterFunction);
  }
  /**
   * Used for decorating the rendered HTML content of a plugin-outlet after it's been rendered
   *
   * `callback` will be called when it is time to decorate it.
   *
   * For example, to add a yellow background to a connector:
   *
   * ```
   * api.decoratePluginOutlet(
   *   "discovery-list-container-top",
   *   (elem, args) => {
   *     if (elem.classList.contains("foo")) {
   *       elem.style.backgroundColor = "yellow";
   *     }
   *   }
   * );
   * ```
   *
   **/
  decoratePluginOutlet(outletName, callback, opts) {
    addPluginOutletDecorator(outletName, callback, opts || {});
  }

  /**
   * Allows altering the topic title in the topic list, and in the topic view
   *
   * topicTitleType can be `topic-title` or `topic-list-item-title`
   *
   * For example, to replace the topic title:
   *
   * ```
   * api.decorateTopicTitle((topicModel, node, topicTitleType) => {
   *   node.innerText = "my new topic title";
   * });
   * ```
   *
   **/
  decorateTopicTitle(callback) {
    addTopicTitleDecorator(callback);
  }

  /**
   * Allows adding icons to the category-link html
   *
   * ```
   * api.addCategoryLinkIcon((category) => {
   *  if (category.someProperty) {
        return "eye"
      }
   * });
   * ```
   *
   **/
  addCategoryLinkIcon(renderer) {
    addExtraIconRenderer(renderer);
  }
  /**
   * Adds a widget to the header-icon ul. The widget must already be created. You can create new widgets
   * in a theme or plugin via an initializer prior to calling this function.
   *
   * ```
   * api.addToHeaderIcons(
   *  createWidget('some-widget')
   * ```
   *
   **/
  addToHeaderIcons(icon) {
    addToHeaderIcons(icon);
  }

  /**
   * Adds an item to the quick access profile panel, before "Log Out".
   *
   * ```
   * api.addQuickAccessProfileItem({
   *   icon: "pencil-alt",
   *   href: "/somewhere",
   *   content: I18n.t("user.somewhere")
   * })
   * ```
   *
   **/
  addQuickAccessProfileItem(item) {
    addQuickAccessProfileItem(item);
  }

  addFeaturedLinkMetaDecorator(decorator) {
    addFeaturedLinkMetaDecorator(decorator);
  }

  /**
   * Adds items to dropdown's in search-advanced-options.
   *
   * ```
   * api.addAdvancedSearchOptions({
   *   inOptionsForUsers:[{
   *     name: I18n.t("search.advanced.in.assigned"),
   *     value: "assigned",
   *   },
   *   {
   *     name: I18n.t("search.advanced.in.not_assigned"),
   *     value: "not_assigned",
   *   },]
   *   statusOptions: [{
   *     name: I18n.t("search.advanced.status.open"),
   *     value: "open"
   *   }]
   * ```
   *
   **/
  addAdvancedSearchOptions(options) {
    addAdvancedSearchOptions(options);
  }

  addSaveableUserField(fieldName) {
    addSaveableUserField(fieldName);
  }
  addSaveableUserOptionField(fieldName) {
    addSaveableUserOptionField(fieldName);
  }
  addPluginReviewableParam(reviewableType, param) {
    addPluginReviewableParam(reviewableType, param);
  }

  /**
   * Change the default category background and text colors in the
   * category creation modal.
   *
   * ```
   * api.setNewCategoryDefaultColors(
   *   'FFFFFF', // background color
   *   '000000'  // text color
   *  )
   * ```
   *
   **/
  setNewCategoryDefaultColors(backgroundColor, textColor) {
    setNewCategoryDefaultColors(backgroundColor, textColor);
  }

  /**
   * Add a callback to modify search results before displaying them.
   *
   * ```
   * api.addSearchResultsCallback((results) => {
   *   results.topics.push(Topic.create({ ... }));
   *   return results;
   * });
   * ```
   *
   */
  addSearchResultsCallback(callback) {
    addSearchResultsCallback(callback);
  }

  /**
   * Add a suggestion shortcut to search menu panel.
   *
   * ```
   * api.addSearchSuggestion("in:assigned");
   * ```
   *
   */
  addSearchSuggestion(value) {
    addSearchSuggestion(value);
  }

  /**
   * Download calendar modal which allow to pick between ICS and Google Calendar
   *
   * ```
   * api.downloadCalendar("title of the event", [
   * {
        startsAt: "2021-10-12T15:00:00.000Z",
        endsAt: "2021-10-12T16:00:00.000Z",
      },
   * ]);
   * ```
   *
   */
  downloadCalendar(title, dates) {
    downloadCalendar(title, dates);
  }

  /**
   * Add a quick search tip shown randomly when the search dropdown is invoked on desktop.
   *
   * Example usage:
   * ```
   * const tip = {
   *    label: "in:docs",
   *    description: I18n.t("search.tips.in_docs"),
   *    clickable: true,
   *    showTopics: true
   * };
   * api.addQuickSearchRandomTip(tip);
   * ```
   *
   */
  addQuickSearchRandomTip(tip) {
    addQuickSearchRandomTip(tip);
  }

  /**
   * Add custom user search options.
   * It is heavily correlated with `register_groups_callback_for_users_search_controller_action` which allows defining custom filter.
   * Example usage:
   * ```
   * api.addUserSearchOption("adminsOnly");

   * register_groups_callback_for_users_search_controller_action(:admins_only) do |groups, user|
   *   groups.where(name: "admins")
   * end
   *
   * {{email-group-user-chooser
   *   options=(hash
   *     includeGroups=true
   *     adminsOnly=true
   *   )
   * }}
   * ```
   */
  addUserSearchOption(value) {
    CUSTOM_USER_SEARCH_OPTIONS.push(value);
  }

  /**
   * Calls a method on a mounted widget whenever an app event happens.
   *
   * For example, if you have a widget with a `key` of `cool-widget` that lives inside the
   * `site-header` component, and you wanted it to respond to `thing:happened`, you could do this:
   *
   * ```
   * api.dispatchWidgetAppEvent('site-header', 'cool-widget', 'thing:happened');
   * ```
   *
   * In this case, the `cool-widget` must have a method called `thingHappened`. The event name
   * is converted to camelCase and used as the method name for you.
   */
  dispatchWidgetAppEvent(mountedComponent, widgetKey, appEvent) {
    this.modifyClass(
      `component:${mountedComponent}`,
      {
        pluginId: `${mountedComponent}/${widgetKey}/${appEvent}`,

        didInsertElement() {
          this._super();
          this.dispatch(appEvent, widgetKey);
        },
      },
      { ignoreMissing: true }
    );
  }

  /**
   * Support for customizing the composer text. By providing a callback. Callbacks should
   * return `null` or `undefined` if you don't need a customization based on the current state.
   *
   * ```
   * api.customizeComposerText({
   *   actionTitle(model) {
   *     if (model.hello) {
   *        return "hello.world";
   *     }
   *   },
   *
   *   saveLabel(model) {
   *     return "my.custom_save_label_key";
   *   }
   * })
   *
   */
  customizeComposerText(callbacks) {
    registerCustomizationCallback(callbacks);
  }
}

// from http://stackoverflow.com/questions/6832596/how-to-compare-software-version-number-using-js-only-number
function cmpVersions(a, b) {
  let i, diff;
  let regExStrip0 = /(\.0+)+$/;
  let segmentsA = a.replace(regExStrip0, "").split(".");
  let segmentsB = b.replace(regExStrip0, "").split(".");
  let l = Math.min(segmentsA.length, segmentsB.length);

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
    const owner = getOwner(this);
    let pluginApi = owner.lookup("plugin-api:main");

    if (!pluginApi) {
      pluginApi = new PluginApi(version, owner);
      owner.registry.register("plugin-api:main", pluginApi, {
        instantiate: false,
      });
    } else {
      // If we are re-using an instance, make sure the container is correct
      pluginApi.container = owner;
    }

    // We are recycling the compatible object, but let's update to the higher version
    if (pluginApi.version < version) {
      pluginApi.version = version;
    }

    return pluginApi;
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
      "`decorateCooked` should be supplied with an `id` option to avoid memory leaks in test mode. The id will be used to ensure the decorator is only applied once."
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
  mixin["_decorate_" + _decorateId++] = on(evt, function (elem) {
    elem = elem || this.element;
    if (elem) {
      cb(elem);
    }
  });
  klass.reopen(mixin);
}
