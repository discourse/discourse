import I18n from "I18n";
import ComposerEditor, {
  addComposerUploadHandler,
  addComposerUploadMarkdownResolver,
  addComposerUploadPreProcessor,
} from "discourse/components/composer-editor";
import {
  addButton,
  apiExtraButtons,
  removeButton,
  replaceButton,
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
import {
  addComposerSaveErrorCallback,
  addPopupMenuOptionsCallback,
} from "discourse/services/composer";
import { addPostClassesCallback } from "discourse/widgets/post";
import {
  addGroupPostSmallActionCode,
  addPostSmallActionClassesCallback,
  addPostSmallActionIcon,
} from "discourse/widgets/post-small-action";
import { addTagsHtmlCallback } from "discourse/lib/render-tags";
import { addToolbarCallback } from "discourse/components/d-editor";
import { addTopicParticipantClassesCallback } from "discourse/widgets/topic-map";
import { addTopicTitleDecorator } from "discourse/components/topic-title";
import { addUserMenuProfileTabItem } from "discourse/components/user-menu/profile-tab-content";
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
import {
  registerHighlightJSLanguage,
  registerHighlightJSPlugin,
} from "discourse/lib/highlight-syntax";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import { registerTopicFooterDropdown } from "discourse/lib/register-topic-footer-dropdown";
import { registerDesktopNotificationHandler } from "discourse/lib/desktop-notifications";
import { replaceFormatter } from "discourse/lib/utilities";
import { replaceTagRenderer } from "discourse/lib/render-tag";
import { registerCustomLastUnreadUrlCallback } from "discourse/models/topic";
import { setNewCategoryDefaultColors } from "discourse/routes/new-category";
import { addSearchResultsCallback } from "discourse/lib/search";
import { addOnKeyDownCallback } from "discourse/widgets/search-menu";
import {
  addQuickSearchRandomTip,
  addSearchSuggestion,
  removeDefaultQuickSearchRandomTips,
} from "discourse/widgets/search-menu-results";
import { addSearchSuggestion as addGlimmerSearchSuggestion } from "discourse/components/search-menu/results/assistant";
import { CUSTOM_USER_SEARCH_OPTIONS } from "select-kit/components/user-chooser";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { consolePrefix } from "discourse/lib/source-identifier";
import { addSectionLink as addCustomCommunitySectionLink } from "discourse/lib/sidebar/custom-community-section-links";
import {
  addSidebarPanel,
  addSidebarSection,
} from "discourse/lib/sidebar/custom-sections";
import {
  registerCustomCategoryLockIcon,
  registerCustomCategorySectionLinkPrefix,
  registerCustomCountable as registerUserCategorySectionLinkCountable,
} from "discourse/lib/sidebar/user/categories-section/category-section-link";
import { registerCustomTagSectionLinkPrefixIcon } from "discourse/lib/sidebar/user/tags-section/base-tag-section-link";
import { REFRESH_COUNTS_APP_EVENT_NAME as REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME } from "discourse/components/sidebar/user/categories-section";
import DiscourseURL from "discourse/lib/url";
import { registerNotificationTypeRenderer } from "discourse/lib/notification-types-manager";
import { registerUserMenuTab } from "discourse/lib/user-menu/tab";
import { registerModelTransformer } from "discourse/lib/model-transformers";
import { registerCustomUserNavMessagesDropdownRow } from "discourse/controllers/user-private-messages";
import { registerFullPageSearchType } from "discourse/controllers/full-page-search";
import { registerHashtagType } from "discourse/lib/hashtag-autocomplete";
import { _addBulkButton } from "discourse/components/modal/topic-bulk-actions";

// If you add any methods to the API ensure you bump up the version number
// based on Semantic Versioning 2.0.0. Please update the changelog at
// docs/CHANGELOG-JAVASCRIPT-PLUGIN-API.md whenever you change the version
// using the format described at https://keepachangelog.com/en/1.0.0/.
export const PLUGIN_API_VERSION = "1.9.0";

// This helper prevents us from applying the same `modifyClass` over and over in test mode.
function canModify(klass, type, resolverName, changes) {
  if (!changes.pluginId) {
    // eslint-disable-next-line no-console
    console.warn(
      consolePrefix(),
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
    return this._lookupContainer("service:current-user");
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

    if (
      this.container.cache[resolverName] ||
      (resolverName === "model:user" &&
        this.container.lookup("service:current-user"))
    ) {
      // eslint-disable-next-line no-console
      console.warn(
        consolePrefix(),
        `"${resolverName}" has already been initialized and registered as a singleton. Move the modifyClass call earlier in the boot process for changes to take effect. https://meta.discourse.org/t/262064`
      );
    }

    const klass = this.container.factoryFor(resolverName);
    if (!klass) {
      if (!opts.ignoreMissing) {
        // eslint-disable-next-line no-console
        console.warn(
          consolePrefix(),
          `"${resolverName}" was not found by modifyClass`
        );
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

      if (klass.class.reopen) {
        klass.class.reopen(changes);
      } else {
        Object.defineProperties(
          klass.class.prototype || klass.class,
          Object.getOwnPropertyDescriptors(changes)
        );
      }
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
    const site = this._lookupContainer("service:site");
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
    this._deprecateDecoratingHamburgerWidgetLinks(name, fn);
    decorateWidget(name, fn);
  }

  _deprecateDecoratingHamburgerWidgetLinks(name, fn) {
    if (
      name === "hamburger-menu:generalLinks" ||
      name === "hamburger-menu:footerLinks"
    ) {
      const siteSettings = this.container.lookup("service:site-settings");

      if (siteSettings.navigation_menu !== "legacy") {
        try {
          const { href, route, label, rawLabel, className } = fn();
          const textContent = rawLabel || I18n.t(label);

          const args = {
            name: className || textContent.replace(/\s+/g, "-").toLowerCase(),
            title: textContent,
            text: textContent,
          };

          if (href) {
            if (DiscourseURL.isInternal(href)) {
              args.href = href;
            } else {
              // Skip external links support for now
              return;
            }
          } else {
            args.route = route;
          }

          this.addCommunitySectionLink(args, name.match(/footerLinks/));
        } catch {
          deprecated(
            `Usage of \`api.decorateWidget('hamburger-menu:generalLinks')\` is incompatible with the \`navigation_menu\` site setting when not set to "legacy". Please use \`api.addCommunitySectionLink\` instead.`,
            { id: "discourse.decorate-widget.hamburger-widget-links" }
          );
        }

        return;
      }
    }
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
      this.container.factoryFor(`widget:${widget}`)?.class;

    if (!widgetClass) {
      // eslint-disable-next-line no-console
      console.error(
        consolePrefix(),
        `attachWidgetAction: Could not find widget ${widget} in registry`
      );
      return;
    }

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
   * Replace an existing button with a widget
   *
   * Example:
   * ```
   * api.replacePostMenuButton("like", {
   *   name: "widget-name",
   *   buildAttrs: (widget) => {
   *     return { post: widget.findAncestorModel() };
   *   },
   *   shouldRender: (widget) => {
   *     const post = widget.findAncestorModel();
   *     return post.id === 1
   *   }
   * });
   **/
  replacePostMenuButton(name, widget) {
    replaceButton(name, widget);
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
      "addFlagProperty has been removed. Use the reviewable API instead.",
      { id: "discourse.add-flag-property" }
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
   * Register a desktop notification handler
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
   * Adds a callback to be called before rendering any small action post
   * that returns custom classes to add to the small action post
   *
   * ```javascript
   * addPostSmallActionClassesCallback(post => {
   *   if (post.actionCode.includes("group")) {
   *     return ["group-small-post"];
   *   }
   * });
   * ```
   **/
  addPostSmallActionClassesCallback(callback) {
    addPostSmallActionClassesCallback(callback);
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
   * Adds a glyph to the legacy user menu after bookmarks
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
   * To customize the new user menu, see api.registerUserMenuTab
   */
  addUserMenuGlyph() {
    deprecated(
      "addUserMenuGlyph has been removed. Use api.registerUserMenuTab instead.",
      { id: "discourse.add-user-menu-glyph" }
    );
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
   *   forceActive: (category, args, router) => router.currentURL === "/a/b/c/d",
   * })
   */
  addNavigationBarItem(item) {
    if (!item["name"]) {
      // eslint-disable-next-line no-console
      console.warn(
        consolePrefix(),
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
   * The passed function is expected to return a promise.
   *
   * Example:
   *
   * api.composerBeforeSave(() => {
   *   return new Promise(() => {
   *     console.log("Before saving, do something!")
   *   })
   * })
   */
  composerBeforeSave(method) {
    Composer.reopen({ beforeSave: method });
  }

  /**
   * Registers a callback function to handle the composer save errors.
   * This allows you to implement custom logic that will happen before
   * the raw error is presented to the user.
   * The passed function is expected to return true if the error was handled,
   * false otherwise.
   *
   * Example:
   *
   * api.addComposerSaveErrorCallback((error) => {
   *   if (error == "my_error") {
   *      //handle error
   *      return true;
   *   }
   *   return false;
   * })
   */
  addComposerSaveErrorCallback(callback) {
    addComposerSaveErrorCallback(callback);
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
   * Register a custom last unread url for a topic list item.
   * If a non-null value is returned, it will be used right away.
   *
   * Example:
   *
   * function testLastUnreadUrl(context) {
   *   return context.urlForPostNumber(1);
   * }
   * api.registerCustomLastUnreadUrlCallback(testLastUnreadUrl);
   **/
  registerCustomLastUnreadUrlCallback(fn) {
    registerCustomLastUnreadUrlCallback(fn);
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
   * Registers custom HighlightJS plugins.
   *
   * See https://highlightjs.readthedocs.io/en/latest/plugin-api.html
   * for instructions on how to define a new plugin for HighlightJS.
   * This API exposes the Function Based Plugins interface
   *
   * Example:
   *
   * let aPlugin = {
       'after:highlightElement': ({ el, result, text }) => {
         console.log(el);
       }
     }
   * api.registerHighlightJSPlugin(aPlugin);
   **/
  registerHighlightJSPlugin(plugin) {
    registerHighlightJSPlugin(plugin);
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
    addUserMenuProfileTabItem(item);
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
    addGlimmerSearchSuggestion(value);
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
   * Add a function to be called when there is a keyDown even on the search-menu widget.
   * This function runs before the default logic, and if one callback returns a falsey value
   * the logic chain will stop, to prevent the core behavior from occurring.
   *
   * Example usage:
   * ```
   * api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
   *  if (searchMenu.term === "stop") {
   *    return false;
   *  }
   * });
   * ```
   *
   */
  addSearchMenuOnKeyDownCallback(fn) {
    addOnKeyDownCallback(fn);
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
   * Remove the default quick search tips shown randomly when the search dropdown is invoked on desktop.
   *
   * Usage:
   * ```
   * api.removeDefaultQuickSearchRandomTips();
   * ```
   *
   */
  removeDefaultQuickSearchRandomTips(tip) {
    removeDefaultQuickSearchRandomTips(tip);
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

  /**
   * Support for adding a navigation link to Sidebar Community section under the "More..." links drawer by returning a
   * class which extends from the BaseSectionLink class interface. See `lib/sidebar/user/community-section/base-section-link.js`
   * for documentation on the BaseSectionLink class interface.
   *
   * ```
   * api.addCommunitySectionLink((baseSectionLink) => {
   *   return class CustomSectionLink extends baseSectionLink {
   *     get name() {
   *       return "bookmarked";
   *     }
   *
   *     get route() {
   *       return "userActivity.bookmarks";
   *     }
   *
   *     get model() {
   *       return this.currentUser;
   *     }
   *
   *     get title() {
   *       return I18n.t("sidebar.sections.topics.links.bookmarked.title");
   *     }
   *
   *     get text() {
   *       return I18n.t("sidebar.sections.topics.links.bookmarked.content");
   *     }
   *   }
   * })
   * ```
   *
   * or
   *
   * ```
   * api.addCommunitySectionLink({
   *   name: "unread",
   *   route: "discovery.unread",
   *   title: I18n.t("some.unread.title"),
   *   text: I18n.t("some.unread.text")
   * })
   * ```
   *
   * @callback addCommunitySectionLinkCallback
   * @param {BaseSectionLink} baseSectionLink - Factory class to inherit from.
   * @returns {BaseSectionLink} - A class that extends BaseSectionLink.
   *
   * @param {(addCommunitySectionLinkCallback|Object)} arg - A callback function or an Object.
   * @param {string} arg.name - The name of the link. Needs to be dasherized and lowercase.
   * @param {string} arg.title - The title attribute for the link.
   * @param {string} arg.text - The text to display for the link.
   * @param {string} [arg.route] - The Ember route name to generate the href attribute for the link.
   * @param {string} [arg.href] - The href attribute for the link.
   * @param {string} [arg.icon] - The FontAwesome icon to display for the link.
   * @param {Boolean} [secondary] - Determines whether the section link should be added to the main or secondary section in the "More..." links drawer.
   */
  addCommunitySectionLink(arg, secondary) {
    addCustomCommunitySectionLink(arg, secondary);
  }

  /**
   * Registers a new countable for section links under Sidebar Categories section on top of the default countables of
   * unread topics count and new topics count.
   *
   * ```
   * api.registerUserCategorySectionLinkCountable({
   *   badgeTextFunction: (count) => {
   *     return I18n.t("custom.open_count", count: count");
   *   },
   *   route: "discovery.openCategory",
   *   shouldRegister: ({ category } => {
   *     return category.custom_fields.enable_open_topics_count;
   *   }),
   *   refreshCountFunction: ({ _topicTrackingState, category } => {
   *     return category.open_topics_count;
   *   }),
   *   prioritizeDefaults: ({ currentUser, category } => {
   *     return category.custom_fields.show_open_topics_count_first;
   *   })
   * })
   * ```
   *
   * @callback badgeTextFunction
   * @param {Integer} count - The count as given by the `refreshCountFunction`.
   * @returns {String} - Text for the badge displayed in the section link.
   *
   * @callback shouldRegister
   * @param {Object} arg
   * @param {Category} arg.category - The category model for the sidebar section link.
   * @returns {Boolean} - Whether the countable should be registered for the sidebar section link.
   *
   * @callback refreshCountFunction
   * @param {Object} arg
   * @param {Category} arg.category - The category model for the sidebar section link.
   * @returns {integer} - The value used to set the property for the count.
   *
   * @callback prioritizeOverDefaults
   * @param {Object} arg
   * @param {Category} arg.category - The category model for the sidebar section link.
   * @param {User} arg.currentUser - The user model for the current user.
   * @returns {boolean} - Whether the countable should be prioritized over the defaults.
   *
   * @param {Object} arg - An object
   * @param {string} arg.badgeTextFunction - Function used to generate the text for the badge displayed in the section link.
   * @param {string} arg.route - The Ember route name to generate the href attribute for the link.
   * @param {Object} [arg.routeQuery] - Object representing the query params that should be appended to the route generated.
   * @param {shouldRegister} arg.shouldRegister - Function used to determine if the countable should be registered for the category.
   * @param {refreshCountFunction} arg.refreshCountFunction - Function used to calculate the value used to set the property for the count whenever the sidebar section link refreshes.
   * @param {prioritizeOverDefaults} args.prioritizeOverDefaults - Function used to determine whether the countable should be prioritized over the default countables of unread/new.
   */
  registerUserCategorySectionLinkCountable({
    badgeTextFunction,
    route,
    routeQuery,
    shouldRegister,
    refreshCountFunction,
    prioritizeOverDefaults,
  }) {
    registerUserCategorySectionLinkCountable({
      badgeTextFunction,
      route,
      routeQuery,
      shouldRegister,
      refreshCountFunction,
      prioritizeOverDefaults,
    });
  }

  /**
   * Changes the lock icon used for a sidebar category section link to indicate that a category is read restricted.
   *
   * @param {String} Name of a FontAwesome 5 icon
   */
  registerCustomCategorySectionLinkLockIcon(icon) {
    return registerCustomCategoryLockIcon(icon);
  }

  /**
   * Register a custom prefix for a sidebar category section link.
   *
   * Example:
   *
   * ```
   * api.registerCustomCategorySectionLinkPrefix({
   *   categoryId: category.id,
   *   prefixType: "icon",
   *   prefixValue: "wrench",
   *   prefixColor: "FF0000"
   * })
   * ```
   *
   * @param {Object} arg - An object
   * @param {string} arg.categoryId - The id of the category
   * @param {string} arg.prefixType - The type of prefix to use. Can be "icon", "image", "text" or "span".
   * @param {string} arg.prefixValue - The value of the prefix to use.
   *                                    For "icon", pass in the name of a FontAwesome 5 icon.
   *                                    For "image", pass in the src of the image.
   *                                    For "text", pass in the text to display.
   *                                    For "span", pass in an array containing two hex color values. Example: `[FF0000, 000000]`.
   * @param {string} arg.prefixColor - The color of the prefix to use. Example: "FF0000".
   */
  registerCustomCategorySectionLinkPrefix({
    categoryId,
    prefixType,
    prefixValue,
    prefixColor,
  }) {
    registerCustomCategorySectionLinkPrefix({
      categoryId,
      prefixType,
      prefixValue,
      prefixColor,
    });
  }

  /**
   * Register a custom prefix for a sidebar tag section link.
   *
   * Example:
   *
   * ```
   * api.registerCustomTagSectionLinkPrefixValue({
   *   tagName: "tag1",
   *   prefixType: "icon",
   *   prefixValue: "wrench",
   *   prefixColor: "#FF0000"
   * });
   * ```
   *
   * @param {Object} arg - An object
   * @param {string} arg.tagName - The name of the tag
   * @param {string} arg.prefixValue - The name of a FontAwesome 5 icon.
   * @param {string} arg.prefixColor - The color represented using hexadecimal to use for the prefix. Example: "#FF0000" or "#FFF".
   */
  registerCustomTagSectionLinkPrefixIcon({
    tagName,
    prefixValue,
    prefixColor,
  }) {
    registerCustomTagSectionLinkPrefixIcon({
      tagName,
      prefixValue,
      prefixColor,
    });
  }

  /**
   * Triggers a refresh of the counts for all category section links under the categories section for a logged in user.
   */
  refreshUserSidebarCategoriesSectionCounts() {
    const appEvents = this._lookupContainer("service:app-events");

    appEvents?.trigger(
      REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME
    );
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Support for adding a Sidebar panel by returning a class which extends from the BaseCustomSidebarPanel
   * class interface. See `lib/sidebar/user/base-custom-sidebar-panel.js` for documentation on the BaseCustomSidebarPanel class
   * interface.
   *
   * ```
   * api.addSidebarPanel((BaseCustomSidebarPanel) => {
   *   const ChatSidebarPanel = class extends BaseCustomSidebarPanel {
   *     get key() {
   *       return "chat";
   *     }
   *     get switchButtonLabel() {
   *       return I18n.t("sidebar.panels.chat.label");
   *     }
   *     get switchButtonIcon() {
   *       return "d-chat";
   *     }
   *     get switchButtonDefaultUrl() {
   *       return "/chat";
   *     }
   *   };
   *   return ChatSidebarPanel;
   * });
   * ```
   */
  addSidebarPanel(func) {
    addSidebarPanel(func);
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Support for setting a Sidebar panel.
   */
  setSidebarPanel(name) {
    this._lookupContainer("service:sidebar-state").setPanel(name);
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Set combined sidebar section mode. In this mode, sections from all panels are displayed together.
   */
  setCombinedSidebarMode() {
    this._lookupContainer("service:sidebar-state").setCombinedMode();
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Set separated sidebar section mode. In this mode, only sections from the current panel are displayed.
   */
  setSeparatedSidebarMode() {
    this._lookupContainer("service:sidebar-state").setSeparatedMode();
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Show sidebar switch panels buttons in separated mode.
   */
  showSidebarSwitchPanelButtons() {
    this._lookupContainer("service:sidebar-state").showSwitchPanelButtons();
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Hide sidebar switch panels buttons in separated mode.
   */
  hideSidebarSwitchPanelButtons() {
    this._lookupContainer("service:sidebar-state").hideSwitchPanelButtons();
  }

  /**
   * Support for adding a Sidebar section by returning a class which extends from the BaseCustomSidebarSection
   * class interface. See `lib/sidebar/user/base-custom-sidebar-section.js` for documentation on the BaseCustomSidebarSection class
   * interface.
   *
   * ```
   * api.addSidebarSection((BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
   *   return class extends BaseCustomSidebarSection {
   *     get name() {
   *       return "chat-channels";
   *     }
   *
   *     get route() {
   *       return "chat";
   *     }
   *
   *     get title() {
   *       return I18n.t("sidebar.sections.chat.title");
   *     }
   *
   *     get text() {
   *       return I18n.t("sidebar.sections.chat.text");
   *     }
   *
   *     get actionsIcon() {
   *       return "cog";
   *     }
   *
   *     get actions() {
   *       return [
   *         { id: "browseChannels", title: "Browse channel", action: () => {} },
   *         { id: "settings", title: "Settings", action: () => {} },
   *       ];
   *     }
   *
   *     get links() {
   *       return [
   *         new (class extends BaseCustomSidebarSectionLink {
   *           get name() {
   *             "dev"
   *           }
   *           get route() {
   *             return "chat.channel";
   *           }
   *           get model() {
   *             return {
   *               channelId: "1",
   *               channelTitle: "dev channel"
   *             };
   *           }
   *           get title() {
   *             return "dev channel";
   *           }
   *           get text() {
   *             return "dev channel";
   *           }
   *           get prefixValue() {
   *             return "icon";
   *           }
   *           get prefixValue() {
   *             return "hashtag";
   *           }
   *           get prefixColor() {
   *             return "000000";
   *           }
   *           get prefixBadge() {
   *             return "lock";
   *           }
   *           get suffixType() {
   *             return "icon";
   *           }
   *           get suffixValue() {
   *             return "circle";
   *           }
   *           get suffixCSSClass() {
   *             return "unread";
   *           }
   *         })(),
   *         new (class extends BaseCustomSidebarSectionLink {
   *           get name() {
   *             "random"
   *           }
   *           get route() {
   *             return "chat.channel";
   *           }
   *           get model() {
   *             return {
   *               channelId: "2",
   *               channelTitle: "random channel"
   *             };
   *           }
   *           get currentWhen() {
   *             return true;
   *           }
   *           get title() {
   *             return "random channel";
   *           }
   *           get text() {
   *             return "random channel";
   *           }
   *           get hoverType() {
   *             return "icon";
   *           }
   *           get hoverValue() {
   *             return "times";
   *           }
   *           get hoverAction() {
   *             return () => {};
   *           }
   *           get hoverTitle() {
   *             return "button title attribute"
   *           }
   *         })()
   *       ];
   *     }
   *   }
   * })
   * ```
   */
  addSidebarSection(func, panelKey = "main") {
    addSidebarSection(func, panelKey);
  }

  /**
   * Register a custom renderer for a notification type or override the
   * renderer of an existing type. See lib/notification-types/base.js for
   * documentation and the default renderer.
   *
   * ```
   * api.registerNotificationTypeRenderer("your_notification_type", (NotificationTypeBase) => {
   *   return class extends NotificationTypeBase {
   *     get label() {
   *       return "some label";
   *     }
   *
   *     get description() {
   *       return "fancy description";
   *     }
   *   };
   * });
   * ```
   * @callback renderDirectorRegistererCallback
   * @param {NotificationTypeBase} The base class from which the returned class should inherit.
   * @returns {NotificationTypeBase} A class that inherits from NotificationTypeBase.
   *
   * @param {string} notificationType - ID of the notification type (i.e. the key value of your notification type in the `Notification.types` enum on the server side).
   * @param {renderDirectorRegistererCallback} func - Callback function that returns a subclass from the class it receives as its argument.
   */
  registerNotificationTypeRenderer(notificationType, func) {
    registerNotificationTypeRenderer(notificationType, func);
  }

  /**
   * Registers a new tab in the user menu. This API method expects a callback
   * that should return a class inheriting from the class (UserMenuTab) that's
   * passed to the callback. See discourse/app/lib/user-menu/tab.js for
   * documentation of UserMenuTab.
   *
   * ```
   * api.registerUserMenuTab((UserMenuTab) => {
   *   return class extends UserMenuTab {
   *     id = "custom-tab-id";
   *     panelComponent = MyCustomPanelGlimmerComponent;
   *     icon = "some-fa5-icon";
   *
   *     get shouldDisplay() {
   *       return this.siteSettings.enable_custom_tab && this.currentUser.admin;
   *     }
   *
   *     get count() {
   *       return this.currentUser.my_custom_notification_count;
   *     }
   *   }
   * });
   * ```
   *
   * @callback customTabRegistererCallback
   * @param {UserMenuTab} The base class from which the returned class should inherit.
   * @returns {UserMenuTab} A class that inherits from UserMenuTab.
   *
   * @param {customTabRegistererCallback} func - Callback function that returns a subclass from the class it receives as its argument.
   */
  registerUserMenuTab(func) {
    registerUserMenuTab(func);
  }

  /**
   * Apply transformation using a callback on a list of model instances of a
   * specific type. Currently, this API only works on lists rendered in the
   * user menu such as notifications, bookmarks and topics (i.e. messages), but
   * it may be extended to other lists in other parts of the app.
   *
   * You can pass an `async` callback to this API and it'll be `await`ed and
   * block rendering until the callback finishes executing.
   *
   * ```
   * api.registerModelTransformer("topic", async (topics) => {
   *   for (const topic of topics) {
   *     const decryptedTitle = await decryptTitle(topic.encrypted_title);
   *     if (decryptedTitle) {
   *       topic.fancy_title = decryptedTitle;
   *     }
   *   }
   * });
   * ```
   *
   * @callback registerModelTransformerCallback
   * @param {Object[]} A list of model instances
   *
   * @param {string} modelName - Model type on which transformation should be applied. Currently valid types are "topic", "notification" and "bookmark".
   * @param {registerModelTransformerCallback} transformer - Callback function that receives a list of model objects of the specified type and applies transformation on them.
   */
  registerModelTransformer(modelName, transformer) {
    registerModelTransformer(modelName, transformer);
  }

  /**
   * Adds a row to the dropdown used on the `userPrivateMessages` route used to navigate between the different user
   * messages pages.
   *
   * @param {string} routeName The Ember route name to transition to when the row is selected in the dropdown
   * @param {string} name The text displayed to represent the row in the dropdown
   * @param {string} [icon] The name of the icon that will be used when displaying the row in the dropdown
   */
  addUserMessagesNavigationDropdownRow(routeName, name, icon) {
    registerCustomUserNavMessagesDropdownRow(routeName, name, icon);
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Adds a new search type which can be selected when visiting the full page search UI.
   *
   * @param {string} translationKey
   * @param {string} searchTypeId
   * @param {function} searchFunc - Available arguments: fullPage controller, search args, searchKey.
   */
  addFullPageSearchType(translationKey, searchTypeId, searchFunc) {
    registerFullPageSearchType(translationKey, searchTypeId, searchFunc);
  }

  /**
   * Registers a hashtag type and its corresponding class.
   * This is used when generating CSS classes in the hashtag-css-generator.
   *
   * @param {string} type - The type of the hashtag.
   * @param {Class} typeClassInstance - The initialized class of the hashtag type, which
   *  needs the `container`.
   */
  registerHashtagType(type, typeClassInstance) {
    registerHashtagType(type, typeClassInstance);
  }

  /**
   * Adds a button to the bulk topic actions modal.
   *
   * ```
   * api.addBulkActionButton({
   *   label: "super_plugin.bulk.enhance",
   *   icon: "magic",
   *   class: "btn-default",
   *   visible: ({ currentUser, siteSettings }) => siteSettings.super_plugin_enabled && currentUser.staff,
   *   async action({ setComponent }) {
   *     await doSomething(this.model.topics);
   *     setComponent(MyBulkModal);
   *   },
   * });
   * ```
   *
   * @callback buttonVisibilityCallback
   * @param {Object} opts
   * @param {Topic[]} opts.topics - the selected topic for the bulk action
   * @param {Category} opts.category - the category in which the action is performed (if applicable)
   * @param {User} opts.currentUser
   * @param {SiteSettings} opts.siteSettings
   * @returns {Boolean} - whether the button should be visible or not
   *
   * @callback buttonAction
   * @param {Object} opts
   * @param {Topic[]} opts.topics - the selected topic for the bulk action
   * @param {Category} opts.category - the category in which the action is performed (if applicable)
   * @param {function} opts.setComponent - render a template in the bulk action modal (pass in an imported component)
   * @param {function} opts.performAndRefresh
   * @param {function} opts.forEachPerformed
   *
   * @param {Object} opts
   * @param {string} opts.label
   * @param {string} opts.icon
   * @param {string} opts.class
   * @param {buttonVisibilityCallback} opts.visible
   * @param {buttonAction} opts.action
   */
  addBulkActionButton(opts) {
    _addBulkButton(opts);
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
    console.warn(consolePrefix(), `Plugin API v${version} is not supported`);
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
      consolePrefix(),
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
  let name = `_decorate_${_decorateId++}`;

  if (id) {
    name += `_${id.replaceAll(/\W/g, "_")}`;
  }

  mixin[name] = on(evt, function (elem) {
    elem = elem || this.element;
    if (elem) {
      cb(elem);
    }
  });

  klass.reopen(mixin);
}
