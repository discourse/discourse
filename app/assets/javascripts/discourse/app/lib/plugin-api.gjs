// If you add any methods to the API ensure you bump up the version number
// based on Semantic Versioning 2.0.0. Please update the changelog at
// docs/CHANGELOG-JAVASCRIPT-PLUGIN-API.md whenever you change the version
// using the format described at https://keepachangelog.com/en/1.0.0/.

export const PLUGIN_API_VERSION = "1.38.0";

import $ from "jquery";
import { h } from "virtual-dom";
import { addAboutPageActivity } from "discourse/components/about-page";
import { addBulkDropdownButton } from "discourse/components/bulk-select-topics-dropdown";
import { addCardClickListenerSelector } from "discourse/components/card-contents-base";
import {
  addApiImageWrapperButtonClickEvent,
  addComposerUploadHandler,
  addComposerUploadMarkdownResolver,
  addComposerUploadPreProcessor,
} from "discourse/components/composer-editor";
import { addPluginDocumentTitleCounter } from "discourse/components/d-document";
import { addToolbarCallback } from "discourse/components/d-editor";
import { addCategorySortCriteria } from "discourse/components/edit-category-settings";
import { forceDropdownForMenuPanels as glimmerForceDropdownForMenuPanels } from "discourse/components/glimmer-site-header";
import { addGlobalNotice } from "discourse/components/global-notice";
import { headerButtonsDAG } from "discourse/components/header";
import { headerIconsDAG } from "discourse/components/header/icons";
import { registeredTabs } from "discourse/components/more-topics";
import { addWidgetCleanCallback } from "discourse/components/mount-widget";
import { addPluginOutletDecorator } from "discourse/components/plugin-connector";
import {
  addPluginReviewableParam,
  registerReviewableActionModal,
} from "discourse/components/reviewable-item";
import { addAdvancedSearchOptions } from "discourse/components/search-advanced-options";
import { addSearchSuggestion } from "discourse/components/search-menu/results/assistant";
import { addItemSelectCallback as addSearchMenuAssistantSelectCallback } from "discourse/components/search-menu/results/assistant-item";
import {
  addQuickSearchRandomTip,
  removeDefaultQuickSearchRandomTips,
} from "discourse/components/search-menu/results/random-quick-tip";
import { addOnKeyUpCallback } from "discourse/components/search-menu/search-term";
import { REFRESH_COUNTS_APP_EVENT_NAME as REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME } from "discourse/components/sidebar/user/categories-section";
import { addTopicParticipantClassesCallback } from "discourse/components/topic-map/topic-participant";
import { setDesktopScrollAreaHeight } from "discourse/components/topic-timeline/container";
import { addTopicTitleDecorator } from "discourse/components/topic-title";
import { setNotificationsLimit as setUserMenuNotificationsLimit } from "discourse/components/user-menu/notifications-list";
import { addUserMenuProfileTabItem } from "discourse/components/user-menu/profile-tab-content";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery/list";
import { registerFullPageSearchType } from "discourse/controllers/full-page-search";
import { registerCustomPostMessageCallback as registerCustomPostMessageCallback1 } from "discourse/controllers/topic";
import { addBeforeLoadMoreCallback as addBeforeLoadMoreNotificationsCallback } from "discourse/controllers/user-notifications";
import { registerCustomUserNavMessagesDropdownRow } from "discourse/controllers/user-private-messages";
import {
  addExtraIconRenderer,
  replaceCategoryLinkRenderer,
} from "discourse/helpers/category-link";
import { addUsernameSelectorDecorator } from "discourse/helpers/decorate-username-selector";
import { registerCustomAvatarHelper } from "discourse/helpers/user-avatar";
import { addBeforeAuthCompleteCallback } from "discourse/instance-initializers/auth-complete";
import {
  PLUGIN_NAV_MODE_SIDEBAR,
  PLUGIN_NAV_MODE_TOP,
  registerAdminPluginConfigNav,
} from "discourse/lib/admin-plugin-config-nav";
import { registerPluginHeaderActionComponent } from "discourse/lib/admin-plugin-header-actions";
import classPrepend, {
  withPrependsRolledBack,
} from "discourse/lib/class-prepend";
import { addPopupMenuOption } from "discourse/lib/composer/custom-popup-menu-options";
import { registerDesktopNotificationHandler } from "discourse/lib/desktop-notifications";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { registerHashtagType } from "discourse/lib/hashtag-type-registry";
import {
  registerHighlightJSLanguage,
  registerHighlightJSPlugin,
} from "discourse/lib/highlight-syntax";
import KeyboardShortcuts, {
  disableDefaultKeyboardShortcuts,
} from "discourse/lib/keyboard-shortcuts";
import { registerModelTransformer } from "discourse/lib/model-transformers";
import { registerNotificationTypeRenderer } from "discourse/lib/notification-types-manager";
import { addGTMPageChangedCallback } from "discourse/lib/page-tracker";
import {
  extraConnectorClass,
  extraConnectorComponent,
} from "discourse/lib/plugin-connectors";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import { registerTopicFooterDropdown } from "discourse/lib/register-topic-footer-dropdown";
import { replaceTagRenderer } from "discourse/lib/render-tag";
import { addTagsHtmlCallback } from "discourse/lib/render-tags";
import { addFeaturedLinkMetaDecorator } from "discourse/lib/render-topic-featured-link";
import {
  addLogSearchLinkClickedCallbacks,
  addSearchResultsCallback,
} from "discourse/lib/search";
import Sharing from "discourse/lib/sharing";
import { addAdminSidebarSectionLink } from "discourse/lib/sidebar/admin-sidebar";
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
import { consolePrefix } from "discourse/lib/source-identifier";
import { includeAttributes } from "discourse/lib/transform-post";
import {
  _addTransformerName,
  _registerTransformer,
  transformerTypes,
} from "discourse/lib/transformer";
import { registerUserMenuTab } from "discourse/lib/user-menu/tab";
import { replaceFormatter } from "discourse/lib/utilities";
import { addCustomUserFieldValidationCallback } from "discourse/mixins/user-fields-validation";
import Composer, {
  registerCustomizationCallback,
} from "discourse/models/composer";
import { addNavItem } from "discourse/models/nav-item";
import { registerCustomLastUnreadUrlCallback } from "discourse/models/topic";
import {
  addSaveableUserField,
  addSaveableUserOptionField,
} from "discourse/models/user";
import { setNewCategoryDefaultColors } from "discourse/routes/new-category";
import { setNotificationsLimit } from "discourse/routes/user-notifications";
import { addComposerSaveErrorCallback } from "discourse/services/composer";
import { addPostClassesCallback } from "discourse/widgets/post";
import { addDecorator } from "discourse/widgets/post-cooked";
import {
  addButton,
  apiExtraButtons,
  removeButton,
  replaceButton,
} from "discourse/widgets/post-menu";
import {
  addGroupPostSmallActionCode,
  addPostSmallActionClassesCallback,
  addPostSmallActionIcon,
} from "discourse/widgets/post-small-action";
import {
  addPostTransformCallback,
  preventCloak,
} from "discourse/widgets/post-stream";
import { disableNameSuppression } from "discourse/widgets/poster-name";
import {
  changeSetting,
  createWidget,
  decorateWidget,
  queryRegistry,
  reopenWidget,
} from "discourse/widgets/widget";
import { isTesting } from "discourse-common/config/environment";
import deprecated from "discourse-common/lib/deprecated";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import {
  iconNode,
  registerIconRenderer,
  replaceIcon,
} from "discourse-common/lib/icon-library";
import { needsHbrTopicList } from "discourse-common/lib/raw-templates";
import { addImageWrapperButton } from "discourse-markdown-it/features/image-controls";
import { CUSTOM_USER_SEARCH_OPTIONS } from "select-kit/components/user-chooser";
import { modifySelectKit } from "select-kit/mixins/plugin-api";

const DEPRECATED_POST_MENU_WIDGETS = [
  "post-menu",
  "post-user-tip-shim",
  "small-user-list",
];

const appliedModificationIds = new WeakMap();

// This helper prevents us from applying the same `modifyClass` over and over in test mode.
function canModify(klass, type, resolverName, changes) {
  if (typeof changes === "function") {
    return true;
  }

  if (!changes.pluginId) {
    // eslint-disable-next-line no-console
    console.warn(
      consolePrefix(),
      "To prevent errors in tests, add a `pluginId` key to your `modifyClass` call. This will ensure the modification is only applied once."
    );
    return true;
  }

  let key = "_" + type + "/" + changes.pluginId + "/" + resolverName;

  if (appliedModificationIds.get(klass.class)?.includes(key)) {
    return false;
  } else {
    const modificationIds = appliedModificationIds.get(klass.class) || [];
    modificationIds.push(key);
    appliedModificationIds.set(klass.class, modificationIds);
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
      if (isTesting()) {
        throw error;
      }
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
    const normalized = this.container.registry.normalize(resolverName);
    if (
      this.container.cache[normalized] ||
      (normalized === "model:user" &&
        this.container.lookup("service:current-user"))
    ) {
      // eslint-disable-next-line no-console
      console.error(
        consolePrefix(),
        `Attempted to modify "${resolverName}", but it was already initialized earlier in the boot process (e.g. via a lookup()). Remove that lookup, or move the modifyClass call earlier in the boot process for changes to take effect. https://meta.discourse.org/t/262064`
      );
      return;
    }

    const klass = this.container.factoryFor(normalized);
    if (!klass) {
      if (!opts.ignoreMissing) {
        // eslint-disable-next-line no-console
        console.warn(
          consolePrefix(),
          `"${normalized}" was not found by modifyClass`
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
    if (
      resolverName === "component:topic-list" ||
      resolverName === "component:topic-list-item"
    ) {
      needsHbrTopicList(true);
    }

    const klass = this._resolveClass(resolverName, opts);
    if (!klass) {
      return;
    }

    if (canModify(klass, "member", resolverName, changes)) {
      delete changes.pluginId;

      if (typeof changes === "function") {
        classPrepend(klass.class, changes);
      } else if (klass.class.reopen) {
        withPrependsRolledBack(klass.class, () => {
          klass.class.reopen(changes);
        });
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
    if (
      resolverName === "component:topic-list" ||
      resolverName === "component:topic-list-item"
    ) {
      needsHbrTopicList(true);
    }

    const klass = this._resolveClass(resolverName, opts);
    if (!klass) {
      return;
    }

    if (canModify(klass, "static", resolverName, changes)) {
      delete changes.pluginId;
      withPrependsRolledBack(klass.class, () => {
        klass.class.reopenClass(changes);
      });
    }

    return klass;
  }

  /**
   * Add a new valid behavior transformer name.
   *
   * Use this API to add a new behavior transformer name that can be used in the `registerValueTransformer` API.
   *
   * Notice that this API must be used in a pre-initializer, executed before `freeze-valid-transformers`, otherwise it will throw an error:
   *
   * Example:
   *
   * // pre-initializers/my-transformers.js
   *
   * export default {
   *   before: "freeze-valid-transformers",
   *
   *   initialize() {
   *     withPluginApi("1.33.0", (api) => {
   *       api.addBehaviorTransformerName("my-unique-transformer-name");
   *     }),
   *   },
   * };
   *
   * @param name the name of the new transformer
   *
   */
  addBehaviorTransformerName(name) {
    _addTransformerName(name, transformerTypes.BEHAVIOR);
  }

  /**
   * Register a transformer to override behavior defined in Discourse.
   *
   * Example: to perform an action before the expected behavior
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   exampleNewAction(); // action performed before the expected behavior
   *
   *   next(); //iterates over the transformer queue processing the behaviors
   * });
   * ```
   *
   * Example: to perform an action after the expected behavior
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   next(); //iterates over the transformer queue processing the behaviors
   *
   *   exampleNewAction(); // action performed after the expected behavior
   * });
   * ```
   *
   * Example: to use a value returned by the expected behavior to decide if an action must be performed
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   const expected = next(); //iterates over the transformer queue processing the behaviors
   *
   *   if (expected === "EXPECTED") {
   *     exampleNewAction(); // action performed after the expected behavior
   *   }
   * });
   * ```
   *
   * Example: to abort the expected behavior based on a condition
   * ```
   * api.registerValueTransformer("example-transformer", ({next, context}) => {
   *   if (context.property) {
   *     // not calling next() on a behavior transformer aborts executing the expected behavior
   *
   *     return;
   *   }
   *
   *   next();
   * });
   * ```
   *
   * @param {string} transformerName the name of the transformer
   * @param {function({next, context})} behaviorCallback callback to be used to transform or override the behavior.
   * @param {*} behaviorCallback.next callback that executes the remaining transformer queue producing the expected
   * behavior. Notice that this includes the default behavior and if next() is not called in your transformer's callback
   * the default behavior will be completely overridden
   * @param {*} [behaviorCallback.context] the optional context in which the behavior is being transformed
   * @returns {boolean} True if the transformer exists, false otherwise.
   */
  registerBehaviorTransformer(transformerName, behaviorCallback) {
    return _registerTransformer(
      transformerName,
      transformerTypes.BEHAVIOR,
      behaviorCallback
    );
  }

  /**
   * Add a new valid value transformer name.
   *
   * Use this API to add a new value transformer name that can be used in the `registerValueTransformer` API.
   *
   * Notice that this API must be used in a pre-initializer, executed before `freeze-valid-transformers`, otherwise it will throw an error:
   *
   * Example:
   *
   * // pre-initializers/my-transformers.js
   *
   * export default {
   *   before: "freeze-valid-transformers",
   *
   *   initialize() {
   *     withPluginApi("1.33.0", (api) => {
   *       api.addValueTransformerName("my-unique-transformer-name");
   *     }),
   *   },
   * };
   *
   * @param name the name of the new transformer
   *
   */
  addValueTransformerName(name) {
    _addTransformerName(name, transformerTypes.VALUE);
  }

  /**
   * Register a transformer to override values defined in Discourse.
   *
   * Example: return a static value
   * ```
   * api.registerValueTransformer("example-transformer", () => "value");
   * ```
   *
   * Example: transform the current value
   * ```
   * api.registerValueTransformer("example-transformer", ({value}) => value * 10);
   * ```
   *
   * Example: transform the current value based on a context property
   * ```
   * api.registerValueTransformer("example-transformer", ({value, context}) => {
   *   if (context.property) {
   *     return value * 10;
   *   }
   *
   *   return value;
   * });
   * ```
   *
   * @param {string} transformerName the name of the transformer
   * @param {function({value, context})} valueCallback callback to be used to transform the value. To avoid potential
   * errors or unexpected behavior the callback must be a pure function, i.e. return the transform value instead of
   * mutating the input value, return the same output for the same input and not have any side effects.
   * @param {*} valueCallback.value the value to be transformed
   * @param {*} [valueCallback.context] the optional context in which the value is being transformed
   * @returns {boolean} True if the transformer exists, false otherwise.
   */
  registerValueTransformer(transformerName, valueCallback) {
    return _registerTransformer(
      transformerName,
      transformerTypes.VALUE,
      valueCallback
    );
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
   *     return "<svg class=\"fa d-icon d-icon-far-face-smile svg-icon\" aria-hidden=\"true\"><use href=\"#far-face-smile\"></use></svg>";
   *   },
   *
   *   // for the places in code that render virtual dom elements
   *   node() {
   *     return h("svg", {
   *          attributes: { class: "fa d-icon d-icon-far-face-smile", "aria-hidden": true },
   *          namespace: "http://www.w3.org/2000/svg"
   *        },[
   *          h("use", {
   *          "href": attributeHook("http://www.w3.org/1999/xlink", `#far-face-smile`),
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
   *   elem => { elem.style.backgroundColor = 'yellow' }
   * );
   * ```
   **/
  decorateCookedElement(callback, opts) {
    opts = opts || {};

    callback = wrapWithErrorHandler(callback, "broken_decorator_alert");

    addDecorator(callback, { afterAdopt: !!opts.afterAdopt });

    if (!opts.onlyStream) {
      this.onAppEvent("decorate-non-stream-cooked-element", callback);
    }
  }

  /**
   * See KeyboardShortcuts.addShortcut documentation.
   **/
  addKeyboardShortcut(shortcut, callback, opts = {}) {
    KeyboardShortcuts.addShortcut(shortcut, callback, opts);
  }

  /**
   * This function is used to disable a "default" keyboard shortcut. You can pass
   * an array of shortcut bindings as strings to disable them.
   *
   * Please note that this function must be called from a pre-initializer.
   *
   * Example:
   * ```
   * api.disableDefaultKeyboardShortcuts(['command+f', 'shift+c']);
   * ```
   **/
  disableDefaultKeyboardShortcuts(bindings) {
    disableDefaultKeyboardShortcuts(bindings);
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
    const widgetName = name.split(":")[0];
    this.#deprecatedWidgetOverride(widgetName, "decorateWidget");

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
      this.container.factoryFor(`widget:${widget}`)?.class;

    if (!widgetClass) {
      // eslint-disable-next-line no-console
      console.error(
        consolePrefix(),
        `attachWidgetAction: Could not find widget ${widget} in registry`
      );
      return;
    }

    this.#deprecatedWidgetOverride(widget, "attachWidgetAction");

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
   *     icon: 'mug-saucer',
   *     className: 'hot-coffee',
   *     title: 'coffee.title',
   *     position: 'first'  // can be `first`, `last` or `second-last-hidden`
   *   };
   * });
   *
   * ```
   *
   * action: may be a string or a function. If it is a string, a widget action
   * will be triggered. If it is function, the function will be called.
   *
   * function will receive a single argument:
   *  {
   *    post:
   *    showFeedback:
   *  }
   *
   *  showFeedback can be called to issue a visual feedback on button press.
   *  It gets a single argument with a localization key.
   *
   *  Example:
   *
   *  api.addPostMenuButton('coffee', () => {
   *    return {
   *      action: ({ post, showFeedback }) => {
   *        drinkCoffee(post);
   *        showFeedback('discourse_plugin.coffee.drink');
   *      },
   *      icon: 'mug-saucer',
   *      className: 'hot-coffee',
   *    }
   *  }
   **/
  addPostMenuButton(name, callback) {
    deprecated(
      "`api.addPostMenuButton` has been deprecated. Use the value transformer `post-menu-buttons` instead.",
      {
        since: "v3.4.0.beta3-dev",
        id: "discourse.post-menu-widget-overrides",
      }
    );

    apiExtraButtons[name] = callback;
    addButton(name, callback);
  }

  /**
   * Add a new button in the post admin menu.
   *
   * Example:
   *
   * ```
   * api.addPostAdminMenuButton((post) => {
   *   return {
   *     action: () => {
   *       alert('You clicked on the coffee button!');
   *     },
   *     icon: 'mug-saucer',
   *     className: 'hot-coffee',
   *     label: 'coffee.title',
   *   };
   * });
   * ```
   **/
  addPostAdminMenuButton(callback) {
    this.container
      .lookup("service:admin-post-menu-buttons")
      .addButton(callback);
  }

  /**
   * Add a new button in the topic admin menu.
   *
   * Example:
   *
   * ```
   * api.addTopicAdminMenuButton((topic) => {
   *   return {
   *     action: () => {
   *       alert('You clicked on the coffee button!');
   *     },
   *     icon: 'mug-saucer',
   *     className: 'hot-coffee',
   *     label: 'coffee.title',
   *   };
   * });
   * ```
   **/
  addTopicAdminMenuButton(callback) {
    this.container
      .lookup("service:admin-topic-menu-buttons")
      .addButton(callback);
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
    deprecated(
      "`api.removePostMenuButton` has been deprecated. Use the value transformer `post-menu-buttons` instead.",
      {
        since: "v3.4.0.beta3-dev",
        id: "discourse.post-menu-widget-overrides",
      }
    );

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
    deprecated(
      "`api.replacePostMenuButton` has been deprecated. Use the value transformer `post-menu-buttons` instead.",
      {
        since: "v3.4.0.beta3-dev",
        id: "discourse.post-menu-widget-overrides",
      }
    );

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
   * Add a new button in the composer's toolbar options popup menu.
   *
   * @callback action
   * @param {Object} toolbarEvent - A toolbar event object.
   * @param {function} toolbarEvent.applySurround - Surrounds the selected text with the given text.
   * @param {function} toolbarEvent.addText - Append the given text to the selected text in the composer.
   *
   * @callback condition
   * @param {Object} composer - The composer service object.
   * @returns {boolean} - Whether the button should be displayed.
   *
   * @param {Object} opts - An Object.
   * @param {string} opts.icon - The name of the FontAwesome icon to display for the button.
   * @param {string} opts.label - The I18n translation key for the button's label.
   * @param {string} opts.shortcut - The keyboard shortcut to apply, NOTE: this will unconditionally add CTRL/META key (eg: m means CTRL+m).
   * @param {action} opts.action - The action to perform when the button is clicked.
   * @param {condition} opts.condition - A condition that must be met for the button to be displayed.
   *
   * @example
   * api.addComposerToolbarPopupMenuOption({
   *   action: (toolbarEvent) => {
   *     toolbarEvent.applySurround("**", "**");
   *   },
   *   icon: 'far-bold',
   *   label: 'composer.bold_some_text',
   *   shortcut: 'm',
   *   condition: (composer) => {
   *     return composer.editingPost;
   *   }
   * });
   **/
  addComposerToolbarPopupMenuOption(opts) {
    addPopupMenuOption(opts);
  }

  addToolbarPopupMenuOptionsCallback(opts) {
    deprecated(
      "`addToolbarPopupMenuOptionsCallback` has been renamed to `addComposerToolbarPopupMenuOption`",
      {
        id: "discourse.add-toolbar-popup-menu-options-callback",
        since: "3.2",
        dropFrom: "3.3",
      }
    );

    this.addComposerToolbarPopupMenuOption(opts);
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
   * Called whenever the "page" changes. This allows us to set up analytics
   * and other tracking.
   *
   * To get notified when the page changes, you can install a hook like so:
   *
   * ```javascript
   * api.onPageChange((url, title) => {
   *   console.log('the page changed to: ' + url + ' and title ' + title);
   * });
   * ```
   **/
  onPageChange(fn) {
    const callback = wrapWithErrorHandler(fn, "broken_page_change_alert");
    this.onAppEvent("page:changed", (data) => callback(data.url, data.title));
  }

  /**
   * Listen for a triggered `AppEvent` from Discourse.
   *
   * ```javascript
   * api.onAppEvent('inserted-custom-html', () => {
   *   console.log('a custom footer was rendered');
   * });
   * ```
   **/
  onAppEvent(name, fn) {
    const appEvents = this._lookupContainer("service:app-events");
    appEvents && appEvents.on(name, fn);
  }

  /**
   * Registers a function to generate custom avatar CSS classes
   * for a particular user.
   *
   * Takes a function that will accept a user as a parameter
   * and return an array of CSS classes to apply.
   *
   * ```javascript
   * api.customUserAvatarClasses(user => {
   *   if (get(user, 'primary_group_name') === 'managers') {
   *     return ['managers'];
   *   }
   * });
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
   * Registers a callback that will be evaluated when infinite scrolling would cause
   * more notifications to be loaded. This can be used to prevent loading more unless
   * a specific condition is met.
   *
   * Example:
   *
   * api.addBeforeLoadMoreNotificationsCallback((controller) => {
   *   return controller.allowLoadMore;
   * });
   */
  addBeforeLoadMoreNotificationsCallback(fn) {
    addBeforeLoadMoreNotificationsCallback(fn);
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
    this.#deprecatedWidgetOverride(widgetName, "changeWidgetSetting");
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
    this.#deprecatedWidgetOverride(name, "reopenWidget");
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
  addHeaderPanel() {
    // eslint-disable-next-line no-console
    console.error(
      consolePrefix(),
      `api.addHeaderPanel: This API was decommissioned. Use api.headerIcons instead.`
    );
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
   * @deprecated
   *
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
   * This API is deprecated. See renderIntoOutlet instead.
   *
   **/
  registerConnectorClass(outletName, connectorName, klass) {
    extraConnectorClass(`${outletName}/${connectorName}`, klass);
  }

  /**
   * Register a component to be rendered in a particular outlet.
   *
   * For example, if the outlet is `user-profile-primary`, you could register
   * a component like
   *
   * ```javascript
   * import MyComponent from "discourse/plugins/my-plugin/components/my-component";
   * api.renderInOutlet('user-profile-primary', MyComponent);
   * ```
   *
   * Alternatively, a component could be defined inline using gjs:
   *
   * ```javascript
   * api.renderInOutlet('user-profile-primary', <template>Hello world</template>);
   * ```
   *
   * Note that when passing a component definition to an outlet like this, the default
   * `@connectorTagName` of the outlet is not used. If you need a wrapper element, you'll
   * need to add it to your component's template.
   *
   * @param {string} outletName - Name of plugin outlet to render into
   * @param {Component} klass - Component class definition to be rendered
   *
   */
  renderInOutlet(outletName, klass) {
    extraConnectorComponent(outletName, klass);
  }

  /**
   * Render a component before the content of a wrapper outlet and does not override it's content
   *
   * For example, if the outlet is `discovery-list-area`, you could register
   * a component like
   *
   * ```javascript
   * import MyComponent from "discourse/plugins/my-plugin/components/my-component";
   * api.renderBeforeWrapperOutlet('discovery-list-area', MyComponent);
   * ```
   *
   * Alternatively, a component could be defined inline using gjs:
   *
   * ```javascript
   * api.renderBeforeWrapperOutlet('discovery-list-area', <template>Before the outlet</template>);
   * ```
   *
   * Note:
   * - the content of the outlet is not overridden when using this API, and unlike the main outlet,
   *   multiple connectors can be registered for the same outlet.
   * - this API only works with wrapper outlets. It won't have any effect on standard outlets.
   * - when passing a component definition to an outlet like this, the default
   * `@connectorTagName` of the outlet is not used. If you need a wrapper element, you'll
   * need to add it to your component's template.
   *
   * @param {string} outletName - Name of plugin outlet to render into
   * @param {Component} klass - Component class definition to be rendered
   *
   */
  renderBeforeWrapperOutlet(outletName, klass) {
    this.renderInOutlet(`${outletName}__before`, klass);
  }

  /**
   * Render a component after the content of a wrapper outlet and does not override it's content
   *
   * For example, if the outlet is `discovery-list-area`, you could register
   * a component like
   *
   * ```javascript
   * import MyComponent from "discourse/plugins/my-plugin/components/my-component";
   * api.renderAfterWrapperOutlet('discovery-list-area', MyComponent);
   * ```
   *
   * Alternatively, a component could be defined inline using gjs:
   *
   * ```javascript
   * api.renderAfterWrapperOutlet('discovery-list-area', <template>After the outlet</template>);
   * ```
   *
   * Note:
   * - the content of the outlet is not overridden when using this API, and unlike the main outlet,
   *   multiple connectors can be registered for the same outlet.
   * - this API only works with wrapper outlets. It won't have any effect on standard outlets.
   * - when passing a component definition to an outlet like this, the default
   * `@connectorTagName` of the outlet is not used. If you need a wrapper element, you'll
   * need to add it to your component's template.
   *
   * @param {string} outletName - Name of plugin outlet to render into
   * @param {Component} klass - Component class definition to be rendered
   *
   */
  renderAfterWrapperOutlet(outletName, klass) {
    this.renderInOutlet(`${outletName}__after`, klass);
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
   * Adds a callback when validating the value of a custom user field in the signup form.
   *
   * If the validation is intended to fail, the callback should return an Ember Object with the
   * following properties: `failed`, `reason`, and `element`.
   *
   * In the case of a failed validation, the `reason` will be displayed to the user
   * and the form will not be submitted.
   *
   *
   * Example:
   *
   * addCustomUserFieldValidationCallback((userField) => {
   *   if (userField.field.name === "my custom user field" && userField.value === "foo") {
   *     return EmberObject.create({
   *       failed: true,
   *       reason: I18n.t("value_can_not_be_foo"),
   *       element: userField.field.element,
   *     });
   *   }
   * });
   **/

  addCustomUserFieldValidationCallback(callback) {
    addCustomUserFieldValidationCallback(callback);
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
   *   customFilter: (category, args, router) => { return category && category.displayName !== 'bug' }
   *   customHref: (category, args, router) => {  if (category && category.displayName) === 'not-a-bug') return "/a-feature"; },
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
   * ```javascript
   * let aPlugin = {
   *   "after:highlightElement": ({ el, result, text }) => {
   *     console.log(el);
   *   }
   * }
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
   *
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
   * @deprecated because modifying an Ember-rendered DOM tree can lead to very unexpected errors. Use CSS or plugin outlet connectors instead
   **/
  decoratePluginOutlet(outletName, callback, opts) {
    deprecated(
      "decoratePluginOutlet is deprecated because modifying an Ember-rendered DOM tree can lead to very unexpected errors. Use CSS or plugin outlet connectors instead",
      { id: "discourse.decorate-plugin-outlet" }
    );
    addPluginOutletDecorator(outletName, callback, opts || {});
  }

  /**
   * Used to set the min and max height for the topic timeline scroll area on desktop. Pass object with min/max key value pairs.
   * Example:
   * api.setDesktopTopicTimelineScrollAreaHeight({ min: 50, max: 100 });
   **/
  setDesktopTopicTimelineScrollAreaHeight(height) {
    setDesktopScrollAreaHeight(height);
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
   * @deprecated because modifying an Ember-rendered DOM tree can lead to very unexpected errors. Use plugin outlet connectors instead
   **/
  decorateTopicTitle(callback) {
    deprecated(
      "decorateTopicTitle is deprecated because modifying an Ember-rendered DOM tree can lead to very unexpected errors. Use plugin outlet connectors instead",
      {
        id: "discourse.decorate-topic-title",
        since: "3.2",
        dropFrom: "3.3",
      }
    );
    addTopicTitleDecorator(callback);
  }

  /**
   * Allows a different limit to be set for fetching recent notifications for the user menu
   *
   * Example setting limit to 5:
   * api.setUserMenuNotificationsLimit(5);
   *
   **/
  setUserMenuNotificationsLimit(limit) {
    setUserMenuNotificationsLimit(limit);
  }

  /**
   * Allows adding icons to the category-link html
   *
   * ```javascript
   * api.addCategoryLinkIcon((category) => {
   *   if (category.someProperty) {
   *     return "eye"
   *   }
   * });
   * ```
   **/
  addCategoryLinkIcon(renderer) {
    addExtraIconRenderer(renderer);
  }

  /**
   * Allows for manipulation of the header icons. This includes, adding, removing, or modifying the order of icons.
   *
   * Only the passing of components is supported, and by default the icons are added to the left of existing icons.
   *
   * Example: Add the chat icon to the header icons after the search icon
   * ```
   * api.headerIcons.add(
   *  "chat",
   *  ChatIconComponent,
   *  { after: "search" }
   * )
   * ```
   *
   * Example: Remove the chat icon from the header icons
   * ```
   * api.headerIcons.delete("chat")
   * ```
   *
   * Example: Reposition the chat icon to be before the user-menu icon and after the hamburger icon
   * ```
   * api.headerIcons.reposition("chat", { before: "user-menu", after: "hamburger" })
   * ```
   *
   * Example: Check if the chat icon is present in the header icons (returns true of false)
   * ```
   * api.headerIcons.has("chat")
   * ```
   *
   * If you are looking to add a button with a dropdown, you can implement a `DMenu` which has a `content` block
   * you want create a button in the header that opens a dropdown panel with additional content.
   *
   * ```
   * const IconWithDropdown = <template>
   *   <DMenu @icon="foo" title={{i18n "title"}}>
   *     <:content as |args|>
   *       dropdown content here
   *       <DButton @action={{args.close}} @icon="bar" />
   *     </:content>
   *   </DMenu>
   * </template>;
   *
   * api.headerIcons.add("icon-name", IconWithDropdown, { before: "search" })
   * ```
   *
   **/
  get headerIcons() {
    return headerIconsDAG();
  }

  /**
   * Allows for manipulation of the header buttons. This includes, adding, removing, or modifying the order of buttons.
   *
   * Only the passing of components is supported, and by default the buttons are added to the left of existing buttons.
   *
   * Example: Add a `foo` button to the header buttons after the auth buttons
   * ```
   * api.headerButtons.add(
   *  "foo",
   *  FooComponent,
   *  { after: "auth" }
   * )
   * ```
   *
   * Example: Remove the `foo` button from the header buttons
   * ```
   * api.headerButtons.delete("foo")
   * ```
   *
   * Example: Reposition the `foo` button to be before the `bar` and after the `baz` button
   * ```
   * api.headerButtons.reposition("foo", { before: "bar", after: "baz" })
   * ```
   *
   * Example: Check if the `foo` button is present in the header buttons (returns true of false)
   * ```
   * api.headerButtons.has("foo")
   * ```
   *
   **/
  get headerButtons() {
    return headerButtonsDAG();
  }

  /**
   * Adds a widget to the header-icon ul. The widget must already be created. You can create new widgets
   * in a theme or plugin via an initializer prior to calling this function.
   *
   * ```
   * api.addToHeaderIcons(
   *  createWidget("some-widget")
   * ```
   *
   **/
  // eslint-disable-next-line no-unused-vars
  addToHeaderIcons(icon) {
    // eslint-disable-next-line no-console
    console.error(
      consolePrefix(),
      `api.addToHeaderIcons: This API was decommissioned. Use api.headerIcons instead.`
    );
  }

  /**
   * Set a callback function to specify the URL used in the home logo.
   *
   * This API allows you change the URL of the home logo. As it receives a callback function, you can
   * dynamically change the URL based on the current user, site settings, or any other context.
   *
   * Example: return a static URL
   * ```
   * api.registerHomeLogoHrefCallback(() => "https://example.com");
   * ```
   *
   * Example: return a dynamic URL based on the current user
   * ```
   * api.registerHomeLogoHrefCallback(() => {
   *   const currentUser = api.getCurrentUser();
   *   return `https://example.com/${currentUser.username}`;
   * });
   * ```
   *
   * Example: return a URL based on a theme-component setting
   * ```
   * api.registerHomeLogoHrefCallback(() => {
   *   return settings.example_logo_url_setting;
   * });
   * ```
   *
   * Example: return a URL based on the route
   * ```
   * api.registerHomeLogoHrefCallback(() => {
   *   if (api.container.lookup("service:discovery").onDiscoveryRoute) {
   *     return "https://forum.example.com/categories";
   *   }
   *
   *   return "https://forum.example.com/";
   * });
   * ```
   *
   * @param {Function} callback - A function that returns the URL to be used in the home logo.
   *
   */
  registerHomeLogoHrefCallback(callback) {
    _registerTransformer(
      "home-logo-href",
      transformerTypes.VALUE,
      ({ value }) => callback(value)
    );
  }

  /**
   * Adds an item to the quick access profile panel, before "Log Out".
   *
   * ```
   * api.addQuickAccessProfileItem({
   *   icon: "pencil",
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

  /**
   * Adds additional params to be sent to the reviewable/:id/perform/:action
   * endpoint for a given reviewable type. This is so plugins can provide more
   * complex reviewable actions that may depend on a custom modal.
   *
   * This is copied from the reviewable model instance when performing an action
   * on the ReviewableItem component.
   *
   * ```
   * api.addPluginReviewableParam("ReviewablePluginType", "some_param");
   * ```
   **/
  addPluginReviewableParam(reviewableType, param) {
    addPluginReviewableParam(reviewableType, param);
  }

  /**
   * Registers a mapping between a JavaScript modal component class and a server-side reviewable
   * action, which is registered via `actions.add` and `build_actions`.
   *
   * For more information about modal classes, which are special Ember components used with
   * the DModal API, see:
   *
   * https://meta.discourse.org/t/using-the-dmodal-api-to-render-modal-windows-aka-popups-dialogs-in-discourse/268304.
   *
   * @param {String} reviewableAction - The action name, as registered in the server-side.
   * @param {Class} modalClass - The actual JavaScript class of the modal.
   *
   * @example
   * ```
   * api.registerReviewableActionModal("approve_category_expert", ExpertGroupChooserModal);
   * ```
   **/
  registerReviewableActionModal(reviewableType, modalClass) {
    registerReviewableActionModal(reviewableType, modalClass);
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
   * Change the number of notifications that are loaded at /my/notifications
   *
   * ```
   * api.setNotificationsLimit(20)
   * ```
   *
   **/
  setNotificationsLimit(limit) {
    setNotificationsLimit(limit);
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
   * Add a callback to search before logging the search record. Return false to prevent logging.
   *
   * ```
   * api.addLogSearchLinkClickedCallbacks((params) => {
   *  if (params.searchResultId === "foo") {
   *   return false;
   *  }
   * });
   * ```
   *
   */
  addLogSearchLinkClickedCallbacks(callback) {
    addLogSearchLinkClickedCallbacks(callback);
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
   * Add a callback that will be evaluated when search menu assistant-items are clicked. Function
   * takes an object as it's only argument. This object includes the updated term, searchTermChanged function,
   * and the usage. If any callbacks return false, the core logic will be halted
   *
   * ```
   * api.addSearchMenuAssistantSelectCallback((args) => {
   *   if (args.usage !== "recent-search") {
   *     return true;
   *   }
   *   args.searchTermChanged(args.updatedTerm)
   *   return false;
   * })
   * ```
   *
   */
  addSearchMenuAssistantSelectCallback(fn) {
    addSearchMenuAssistantSelectCallback(fn);
  }

  /**
   * Force a given menu panel (search-menu, user-menu) to be displayed as dropdown if ANY of the passed `classNames` are included in the `classList` of a menu panel.
   * This can be useful for plugins as the default behavior is to add a 'slide-in' behavior to a menu panel if you are viewing on a small screen. eg. mobile.
   * Sometimes when we are rendering the menu panel in a non-standard way we don't want this behavior and want to force the menu panel to be displayed as a dropdown.
   *
   * The `classNames` param can be passed as a single string or an array of strings. This way you can disable the 'slide-in' behavior for multiple menu panels.
   *
   * ```
   * api.forceDropdownForMenuPanels(["search-menu-panel", "user-menu"]);
   * ```
   *
   */
  forceDropdownForMenuPanels(classNames) {
    glimmerForceDropdownForMenuPanels(classNames);
  }

  /**
   * Download calendar modal which allow to pick between ICS and Google Calendar. Optionally, recurrence rule can be specified - https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10
   *
   * ```javascript
   * api.downloadCalendar("title of the event",
   *   [
   *     {
   *       startsAt: "2021-10-12T15:00:00.000Z",
   *       endsAt: "2021-10-12T16:00:00.000Z",
   *     },
   *   ],
   *   { recurrenceRule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR", location: "Paris", details: "Foo" }
   * );
   * ```
   */
  downloadCalendar(title, dates, options = {}) {
    downloadCalendar(title, dates, options);
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
    addOnKeyUpCallback(fn);
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
  removeDefaultQuickSearchRandomTips() {
    removeDefaultQuickSearchRandomTips();
  }

  /**
   * Add custom user search options.
   * It is heavily correlated with `register_groups_callback_for_users_search_controller_action` which allows defining custom filter.
   * Example usage:
   *
   * ```
   * api.addUserSearchOption("adminsOnly");
   *
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
   * @param {String} Name of a FontAwesome icon
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
   *                                    For "icon", pass in the name of a FontAwesome icon.
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
   * @param {string} arg.prefixValue - The name of a FontAwesome icon.
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
   * Support for adding links to specific admin sidebar sections.
   *
   * This is intended to replace the admin-menu plugin outlet from
   * the old admin horizontal nav.
   *
   * ```javascript
   * api.addAdminSidebarSectionLink("root", {
   *   name: "unique_link_name",
   *   label: "admin.some.i18n.label.key",
   *   route: "(optional) emberRouteId",
   *   href: "(optional) can be used instead of the route",
   * }
   * ```
   *
   * @param {String} sectionName - The name of the admin sidebar section to add the link to.
   * @param {Object} link - A link object representing a section link for the sidebar.
   * @param {string} link.name - The name of the link. Needs to be dasherized and lowercase.
   * @param {string} link.title - The title attribute for the link.
   * @param {string} link.text - The text to display for the link.
   * @param {string} [link.route] - The Ember route name to generate the href attribute for the link.
   * @param {string} [link.href] - The href attribute for the link.
   * @param {string} [link.icon] - The FontAwesome icon to display for the link.
   */
  addAdminSidebarSectionLink(sectionName, link) {
    addAdminSidebarSectionLink(sectionName, link);
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Support for setting a Sidebar panel.
   */
  setSidebarPanel(name) {
    this._lookupContainer("service:sidebar-state")?.setPanel(name);
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Support for getting the current Sidebar panel.
   */
  getSidebarPanel() {
    return this._lookupContainer("service:sidebar-state")?.currentPanel;
  }

  /**
   * EXPERIMENTAL. Do not use.
   * Set combined sidebar section mode. In this mode, sections from all panels are displayed together.
   */
  setCombinedSidebarMode() {
    this._lookupContainer("service:sidebar-state")?.setCombinedMode();
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
    this._lookupContainer("service:sidebar-state")?.hideSwitchPanelButtons();
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
   *       return "gear";
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
   *           get prefixType() {
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
   *             return "xmark";
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
   *     icon = "some-fa-icon";
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
   * @param {function} fn - Function that will be called before the auth complete logic is run
   * in instance-initializers/auth-complete.js. If any single callback returns false, the
   * auth-complete logic will be aborted.
   */
  addBeforeAuthCompleteCallback(fn) {
    addBeforeAuthCompleteCallback(fn);
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
   *   icon: wand-magic,
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
   * @param {string} opts.actionType - type of the action, either performAndRefresh or setComponent
   */
  addBulkActionButton(opts) {
    addBulkDropdownButton(opts);
  }

  /**
   * Include the passed user field property in the Admin User Field save request.
   * This is useful for plugins that are adding additional columns to the user field model and want
   * to save the new property values alongside the default user field properties (all under the same save call)
   *
   *
   * ```
   * api.includeUserFieldPropertyOnSave("property_one");
   * api.includeUserFieldPropertyOnSave("property_two");
   * ```
   *
   */
  includeUserFieldPropertyOnSave(userFieldProperty) {
    this.container
      .lookup("service:admin-custom-user-fields")
      .addProperty(userFieldProperty);
  }

  /**
   * Adds a custom button to the composer preview's image wrapper
   *
   *
   * ```
   * api.addComposerImageWrapperButton(
   *   "My Custom Button",
   *   "custom-button-class"
   *   "lock"
   *   (event) => { console.log("Custom button clicked", event)
   * });
   *
   * ```
   *
   */
  addComposerImageWrapperButton(label, btnClass, icon, fn) {
    addImageWrapperButton(label, btnClass, icon);
    addApiImageWrapperButtonClickEvent(fn);
  }

  /**
   * Defines a list of links used in the adminPlugins.show page for
   * a specific plugin. Each link must have:
   *
   * * route
   * * label OR text
   *
   * And the mode must be one of "sidebar" or "top", which controls
   * where in the admin plugin show UI the links will be displayed.
   */
  addAdminPluginConfigurationNav(pluginId, mode, links) {
    if (!pluginId) {
      // eslint-disable-next-line no-console
      console.warn(consolePrefix(), "A pluginId must be provided!");
      return;
    }

    const validModes = [PLUGIN_NAV_MODE_SIDEBAR, PLUGIN_NAV_MODE_TOP];
    if (!validModes.includes(mode)) {
      // eslint-disable-next-line no-console
      console.warn(
        consolePrefix(),
        `${mode} is an invalid mode for admin plugin config pages, only ${validModes} are usable.`
      );
      return;
    }

    registerAdminPluginConfigNav(pluginId, mode, links);
  }

  /**
   * Adds a custom site activity item in the new /about page. Requires using
   * the `register_stat` server-side API to serialize the needed data to the
   * frontend.
   *
   * ```
   * api.addAboutPageActivity("released_songs", (periods) => {
   *   return {
   *     icon: "guitar",
   *     class: "released-songs",
   *     activityText: `${periods["last_year"]} released songs`,
   *     period: "in the last year",
   *   };
   * });
   * ```
   *
   * The above example would require the `register_stat` server-side API to be
   * used like this:
   *
   * ```ruby
   * register_stat("released_songs", expose_via_api: true) do
   *   {
   *     last_year: Songs.where("released_at > ?", 1.year.ago).count,
   *     last_month: Songs.where("released_at > ?", 1.month.ago).count,
   *   }
   * end
   * ```
   *
   * @callback activityItemConfig
   * @param {Object} periods - an object containing the periods that the block given to the `register_stat` server-side API returns.
   * @returns {Object} - configuration object for the site activity item. The object must contain the following properties: `icon`, `class`, `activityText` and `period`.
   *
   * @param {string} name - a string that matches the string given to the `register_stat` server-side API.
   * @param {activityItemConfig} func - a callback that returns an object containing properties for the custom site activity item.
   */
  addAboutPageActivity(name, func) {
    addAboutPageActivity(name, func);
  }

  /**
   * Registers a component class that will be rendered within the AdminPageHeader component
   * only on plugins using the AdminPluginConfigPage and the new plugin "show" route.
   *
   * This component will be passed an `@actions` argument, with Primary, Default, Danger,
   * and Wrapped keys, which can be used for various different types of buttons (Wrapped
   * should be used only in very rare scenarios).
   *
   * This component would be used for actions that should be present on the entire UI
   * for that plugin -- one example is "Create export" for chat.
   *
   * @param {string} pluginId - The `dasherizedName` of the plugin using this component.
   * @param {Class} componentClass - The JS class of the component to render.
   */
  registerPluginHeaderActionComponent(pluginId, componentClass) {
    registerPluginHeaderActionComponent(pluginId, componentClass);
  }

  /**
   * Registers a new tab to be displayed in "more topics" area at the bottom of a topic page.
   *
   * ```gjs
   *  api.registerMoreTopicsTab({
   *    id: "other-topics",
   *    name: i18n("other_topics.tab"),
   *    component: <template>tbd</template>,
   *    condition: ({ topic }) => topic.otherTopics?.length > 0,
   *  });
   * ```
   *
   * You can additionally use more-topics-tabs value transformer to conditionally show/hide
   * specific tabs.
   *
   * ```js
   * api.registerValueTransformer("more-topics-tabs", ({ value, context }) => {
   *   if (context.user?.aFeatureFlag) {
   *     // Remove "suggested" from the topics page
   *     return value.filter(
   *       (tab) =>
   *         context.currentContext !== "topic" ||
   *         tab.id !== "suggested-topics"
   *     );
   *   }
   * });
   * ```
   *
   * @callback tabCondition
   * @param {Object} opts
   * @param {"topic"|"pm"} opts.context - the type of the current page
   * @param {Topic} opts.topic - the current topic
   *
   * @param {Object} tab
   * @param {string} tab.id - an identifier used in more-topics-tabs value transformer
   * @param {string} tab.name - a name displayed on the tab
   * @param {string} tab.icon - an optional icon displayed on the tab
   * @param {Class} tab.component - contents of the tab
   * @param {tabCondition} tab.condition - an optional callback to conditionally show the tab
   */
  registerMoreTopicsTab(tab) {
    registeredTabs.push(tab);
  }

  #deprecatedWidgetOverride(widgetName, override) {
    // insert here the code to handle widget deprecations, e.g. for the header widgets we used:
    // if (DEPRECATED_HEADER_WIDGETS.includes(widgetName)) {
    //   this.container.lookup("service:header").anyWidgetHeaderOverrides = true;
    //   deprecated(
    //     `The ${widgetName} widget has been deprecated and ${override} is no longer a supported override.`,
    //     {
    //       since: "v3.3.0.beta1-dev",
    //       id: "discourse.header-widget-overrides",
    //       url: "https://meta.discourse.org/t/316549",
    //     }
    //   );
    // }

    if (DEPRECATED_POST_MENU_WIDGETS.includes(widgetName)) {
      deprecated(
        `The ${widgetName} widget has been deprecated and ${override} is no longer a supported override.`,
        {
          since: "v3.4.0.beta3-dev",
          id: "discourse.post-menu-widget-overrides",
        }
      );
    }
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
    const owner = getOwnerWithFallback(this);
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
 * Executes the provided callback function with the `PluginApi` object if the specified API version is available.
 *
 * @param {number} version - The version of the API that the plugin is coded against.
 * @param {(api: PluginApi, opts: object) => void} apiCodeCallback - The callback function to execute if the API version is available
 * @param {object} [opts] - Optional additional options to pass to the callback function.
 * @returns {*} The result of the `callback` function, if executed
 */
export function withPluginApi(version, apiCodeCallback, opts) {
  opts = opts || {};

  const api = getPluginApi(version);
  if (api) {
    return apiCodeCallback(api, opts);
  }
}
