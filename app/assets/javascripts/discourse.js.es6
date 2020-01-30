/*global Mousetrap:true*/
import { buildResolver } from "discourse-common/resolver";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { computed } from "@ember/object";
import FocusEvent from "discourse-common/mixins/focus-event";
import EmberObject from "@ember/object";
import deprecated from "discourse-common/lib/deprecated";

const _pluginCallbacks = [];

const Discourse = Ember.Application.extend(FocusEvent, {
  rootElement: "#main",
  _docTitle: document.title,
  RAW_TEMPLATES: {},
  __widget_helpers: {},
  customEvents: {
    paste: "paste"
  },

  reset() {
    this._super(...arguments);

    Mousetrap.reset();
  },

  getURL(url) {
    if (!url) return url;

    // if it's a non relative URL, return it.
    if (url !== "/" && !/^\/[^\/]/.test(url)) return url;

    if (url[0] !== "/") url = "/" + url;
    if (url.startsWith(Discourse.BaseUri)) return url;

    return Discourse.BaseUri + url;
  },

  getURLWithCDN(url) {
    url = Discourse.getURL(url);
    // only relative urls
    if (Discourse.CDN && /^\/[^\/]/.test(url)) {
      url = Discourse.CDN + url;
    } else if (Discourse.S3CDN) {
      url = url.replace(Discourse.S3BaseUrl, Discourse.S3CDN);
    }
    return url;
  },

  Resolver: buildResolver("discourse"),

  @observes("_docTitle", "hasFocus", "contextCount", "notificationCount")
  _titleChanged() {
    let title = this._docTitle || Discourse.SiteSettings.title;

    // if we change this we can trigger changes on document.title
    // only set if changed.
    if ($("title").text() !== title) {
      $("title").text(title);
    }

    let displayCount = this.displayCount;
    let dynamicFavicon = this.currentUser && this.currentUser.dynamic_favicon;
    if (displayCount > 0 && !dynamicFavicon) {
      title = `(${displayCount}) ${title}`;
    }

    document.title = title;
  },

  @discourseComputed("contextCount", "notificationCount")
  displayCount() {
    return this.currentUser &&
      this.currentUser.get("title_count_mode") === "notifications"
      ? this.notificationCount
      : this.contextCount;
  },

  @observes("contextCount", "notificationCount")
  faviconChanged() {
    if (this.currentUser && this.currentUser.get("dynamic_favicon")) {
      let url = Discourse.SiteSettings.site_favicon_url;

      // Since the favicon is cached on the browser for a really long time, we
      // append the favicon_url as query params to the path so that the cache
      // is not used when the favicon changes.
      if (/^http/.test(url)) {
        url = Discourse.getURL("/favicon/proxied?" + encodeURIComponent(url));
      }

      var displayCount = this.displayCount;

      new window.Favcount(url).set(displayCount);
    }
  },

  updateContextCount(count) {
    this.set("contextCount", count);
  },

  updateNotificationCount(count) {
    if (!this.hasFocus) {
      this.set("notificationCount", count);
    }
  },

  incrementBackgroundContextCount() {
    if (!this.hasFocus) {
      this.set("backgroundNotify", true);
      this.set("contextCount", (this.contextCount || 0) + 1);
    }
  },

  @observes("hasFocus")
  resetCounts() {
    if (this.hasFocus && this.backgroundNotify) {
      this.set("contextCount", 0);
    }
    this.set("backgroundNotify", false);

    if (this.hasFocus) {
      this.set("notificationCount", 0);
    }
  },

  authenticationComplete(options) {
    // TODO, how to dispatch this to the controller without the container?
    const loginController = Discourse.__container__.lookup("controller:login");
    return loginController.authenticationComplete(options);
  },

  // Start up the Discourse application by running all the initializers we've defined.
  start() {
    $("noscript").remove();

    Object.keys(requirejs._eak_seen).forEach(function(key) {
      if (/\/pre\-initializers\//.test(key)) {
        const module = requirejs(key, null, null, true);
        if (!module) {
          throw new Error(key + " must export an initializer.");
        }

        const init = module.default;
        const oldInitialize = init.initialize;
        init.initialize = function() {
          oldInitialize.call(this, Discourse.__container__, Discourse);
        };

        Discourse.initializer(init);
      }
    });

    Object.keys(requirejs._eak_seen).forEach(function(key) {
      if (/\/initializers\//.test(key)) {
        const module = requirejs(key, null, null, true);
        if (!module) {
          throw new Error(key + " must export an initializer.");
        }

        const init = module.default;
        const oldInitialize = init.initialize;
        init.initialize = function() {
          oldInitialize.call(this, Discourse.__container__, Discourse);
        };

        Discourse.instanceInitializer(init);
      }
    });

    // Plugins that are registered via `<script>` tags.
    const withPluginApi = requirejs("discourse/lib/plugin-api").withPluginApi;
    let initCount = 0;
    _pluginCallbacks.forEach(function(cb) {
      Discourse.instanceInitializer({
        name: "_discourse_plugin_" + ++initCount,
        after: "inject-objects",
        initialize() {
          withPluginApi(cb.version, cb.code);
        }
      });
    });
  },

  @discourseComputed("currentAssetVersion", "desiredAssetVersion")
  requiresRefresh(currentAssetVersion, desiredAssetVersion) {
    return desiredAssetVersion && currentAssetVersion !== desiredAssetVersion;
  },

  _registerPluginCode(version, code) {
    _pluginCallbacks.push({ version, code });
  },

  assetVersion: computed({
    get() {
      return this.currentAssetVersion;
    },
    set(key, val) {
      if (val) {
        if (this.currentAssetVersion) {
          this.set("desiredAssetVersion", val);
        } else {
          this.set("currentAssetVersion", val);
        }
      }
      return this.currentAssetVersion;
    }
  })
}).create();

Object.defineProperty(Discourse, "Model", {
  get() {
    deprecated("Use an `@ember/object` instead of Discourse.Model", {
      since: "2.4.0",
      dropFrom: "2.5.0"
    });
    return EmberObject;
  }
});

export default Discourse;
