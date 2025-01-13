/* eslint-disable ember/no-private-routing-service */
import EmberObject from "@ember/object";
import { setOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import $ from "jquery";
import getURL, { withoutPrefix } from "discourse/lib/get-url";
import LockOn from "discourse/lib/lock-on";
import offsetCalculator from "discourse/lib/offset-calculator";
import { defaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Session from "discourse/models/session";
import { isTesting } from "discourse-common/config/environment";

const rewrites = [];
export const TOPIC_URL_REGEXP = /\/t\/([^\/]*[^\d\/][^\/]*)\/(\d+)\/?(\d+)?/;

// We can add links here that have server side responses but not client side.
const SERVER_SIDE_ONLY = [
  /^\/assets\//,
  /^\/uploads\//,
  /^\/secure-media-uploads\//,
  /^\/secure-uploads\//,
  /^\/stylesheets\//,
  /^\/site_customizations\//,
  /^\/raw\//,
  /^\/posts\/\d+\/raw/,
  /^\/raw\/\d+/,
  /\.rss$/,
  /\.json$/,
  /^\/logs($|\/)/,
  /^\/admin\/customize\/watched_words\/action\/[^\/]+\/download$/,
  /^\/pub\//,
  /^\/invites\//,
  /^\/styleguide/,
];

// The amount of height (in pixels) that we factor in when jumpEnd is called so
// that we show a little bit of the post text even on mobile devices instead of
// scrolling to "suggested topics".
const JUMP_END_BUFFER = 250;

const ALLOWED_CANONICAL_PARAMS = ["page"];
const TRAILING_SLASH_REGEX = /\/$/;

export function rewritePath(path) {
  const params = path.split("?");

  let result = params[0];
  rewrites.forEach((rw) => {
    if ((rw.opts.exceptions || []).some((ex) => path.startsWith(ex))) {
      return;
    }
    result = result.replace(rw.regexp, rw.replacement);
  });

  if (params.length > 1) {
    result += `?${params[1]}`;
  }

  return result;
}

export function clearRewrites() {
  rewrites.length = 0;
}

export function userPath(subPath) {
  return getURL(subPath ? `/u/${subPath}` : "/u");
}

export function groupPath(subPath) {
  return getURL(subPath ? `/g/${subPath}` : "/g");
}

let _jumpScheduled = false;
let _transitioning = false;
let lockOn = null;

class DiscourseURL extends EmberObject {
  isJumpScheduled() {
    return _transitioning || _jumpScheduled;
  }

  // Jumps to a particular post in the stream
  jumpToPost(postNumber, opts) {
    opts = opts || {};
    const holderId = `#post_${postNumber}`;

    _transitioning = postNumber > 1;

    schedule("afterRender", () => {
      if (opts.jumpEnd) {
        let $holder = $(holderId);
        let holderHeight = $holder.height();
        let windowHeight = $(window).height() - offsetCalculator();

        if (holderHeight > windowHeight) {
          $(window).scrollTop(
            $holder.offset().top + (holderHeight - JUMP_END_BUFFER)
          );
          _transitioning = false;
          return;
        }
      }

      if (postNumber === 1 && !opts.anchor) {
        $(window).scrollTop(0);
        _transitioning = false;
        return;
      }

      let selector;
      let holder;

      if (opts.anchor) {
        selector = `#main #${opts.anchor}, a[name=${opts.anchor}]`;
        holder = document.querySelector(selector);
      }

      if (!holder) {
        selector = holderId;
        holder = document.querySelector(selector);
      }

      if (lockOn) {
        lockOn.clearLock();
      }

      lockOn = new LockOn(selector, {
        originalTopOffset: opts.originalTopOffset,
        finished() {
          _transitioning = false;
          lockOn = null;
        },
      });

      if (holder && opts.skipIfOnScreen) {
        const elementTop = lockOn.elementTop();
        const scrollTop = $(window).scrollTop();
        const windowHeight = $(window).height() - offsetCalculator();
        const height = $(holder).height();

        if (
          elementTop > scrollTop &&
          elementTop + height < scrollTop + windowHeight
        ) {
          _transitioning = false;
          return;
        }
      }

      lockOn.lock();
      if (lockOn.elementTop() < 1) {
        _transitioning = false;
        return;
      }
    });
  }

  replaceState(path) {
    if (path.startsWith("#")) {
      path = this.routerService.currentURL.replace(/#.*$/, "") + path;
    }

    path = withoutPrefix(path);

    if (this.routerService.currentURL !== path) {
      // Always use replaceState in the next runloop to prevent weird routes changing
      // while URLs are loading. For example, while a topic loads it sets `currentPost`
      // which triggers a replaceState even though the topic hasn't fully loaded yet!
      next(() => {
        // Using the private `_routerMicrolib` is not ideal, but Ember doesn't provide
        // any other way for us to do `history.replaceState` without a full transition
        this.router._routerMicrolib.replaceURL(path);
      });
    }
  }

  pushState(path) {
    path = withoutPrefix(path);
    this.router._routerMicrolib.updateURL(path);
  }

  routeToTag(a) {
    // skip when we are provided nowhere to route to
    if (!a || !a.href) {
      return false;
    }

    if (a.host && a.host !== document.location.host) {
      document.location = a.href;
      return false;
    }

    return this.routeTo(a.href);
  }

  /**
    Our custom routeTo method is used to intelligently overwrite default routing
    behavior.

    It contains the logic necessary to route within a topic using replaceState to
    keep the history intact.
  **/
  routeTo(path, opts) {
    opts = opts || {};

    if (isEmpty(path)) {
      return;
    }

    if (Session.currentProp("requiresRefresh") && !this.isComposerOpen) {
      return this.redirectTo(path);
    }

    const pathname = path.replace(/^(https?\:)?\/\/[^\/]+/, "");

    if (!this.isInternal(path)) {
      return this.redirectTo(path);
    }

    const serverSide = SERVER_SIDE_ONLY.some((r) => pathname.match(r));
    if (serverSide) {
      this.redirectTo(path);
      return;
    }

    // Scroll to the same page, different anchor
    const m = /^#(.+)$/.exec(path);
    if (m) {
      this.jumpToElement(m[1]);
      return this.replaceState(path);
    }

    const oldPath = this.routerService.currentURL;

    path = path.replace(/^(https?\:)?\/\/[^\/]+/, "");

    // handle prefixes
    if (path.startsWith("/")) {
      path = withoutPrefix(path);
    }

    if (typeof opts.afterRouteComplete === "function") {
      schedule("afterRender", opts.afterRouteComplete);
    }

    if (this.navigatedToPost(oldPath, path, opts)) {
      return;
    }

    if (oldPath === path || this.refreshedHomepage(oldPath, path)) {
      // If navigating to the same path, refresh the route
      this.routerService.refresh();
    }

    // Navigating to empty string is the same as root
    if (path === "") {
      path = "/";
    }

    return this.handleURL(path, opts);
  }

  routeToUrl(url, opts = {}) {
    this.routeTo(getURL(url), opts);
  }

  rewrite(regexp, replacement, opts) {
    rewrites.push({ regexp, replacement, opts: opts || {} });
  }

  redirectAbsolute(url) {
    // Redirects will kill a test runner
    if (isTesting()) {
      return true;
    }
    window.location = url;
    return true;
  }

  redirectTo(url) {
    return this.redirectAbsolute(getURL(url));
  }

  // Determines whether a URL is internal or not
  isInternal(url) {
    if (!url?.length) {
      return false;
    }

    if (url.startsWith("//")) {
      url = "http:" + url;
    }

    if (url.startsWith("http://") || url.startsWith("https://")) {
      return (
        url.startsWith(this.origin) ||
        url.replace(/^http/, "https").startsWith(this.origin) ||
        url.replace(/^https/, "http").startsWith(this.origin)
      );
    }

    try {
      const parsedUrl = new URL(url, this.origin);
      if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
        return false;
      }
    } catch {
      return false;
    }

    return true;
  }

  /**
    If the URL is in the topic form, /t/something/:topic_id/:post_number
    then we want to apply some special logic. If the post_number changes within the
    same topic, use replaceState and instruct our controller to load more posts.
  **/
  navigatedToPost(oldPath, path, routeOpts) {
    const newMatches = TOPIC_URL_REGEXP.exec(path);
    const newTopicId = newMatches ? newMatches[2] : null;

    if (newTopicId) {
      const oldMatches = TOPIC_URL_REGEXP.exec(oldPath);
      const oldTopicId = oldMatches ? oldMatches[2] : null;

      // If the topic_id is the same
      if (oldTopicId === newTopicId) {
        this.replaceState(path);

        const topicController = this.container.lookup("controller:topic");
        const opts = {};
        const postStream = topicController.get("model.postStream");

        if (newMatches[3]) {
          opts.nearPost = newMatches[3];
        }
        if (path.match(/last$/)) {
          opts.nearPost = topicController.get("model.highest_post_number");
        }

        if (!routeOpts.keepFilter) {
          opts.cancelFilter = true;
        }

        postStream.refresh(opts).then(() => {
          const closest = postStream.closestPostNumberFor(opts.nearPost || 1);
          topicController.setProperties({
            "model.currentPost": closest,
            enteredAt: Date.now().toString(),
          });

          this.appEvents.trigger("post:highlight", closest);
          const jumpOpts = {
            skipIfOnScreen: routeOpts.skipIfOnScreen,
            jumpEnd: routeOpts.jumpEnd,
          };

          const anchorMatch = /#(.+)$/.exec(path);
          if (anchorMatch) {
            jumpOpts.anchor = anchorMatch[1];
          }

          this.jumpToPost(closest, jumpOpts);
        });

        // Abort routing, we have replaced our state.
        return true;
      }
    }

    return false;
  }

  /**
    @private

    Handle the custom case of routing to the root path from itself.

    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  refreshedHomepage(oldPath, path) {
    const homepage = defaultHomepage();

    return (
      (path === "/" || path === "/" + homepage) &&
      (oldPath === "/" || oldPath === "/" + homepage)
    );
  }

  // This has been extracted so it can be tested.
  get origin() {
    const prefix = getURL("/");
    return window.location.origin + (prefix === "/" ? "" : prefix);
  }

  get isComposerOpen() {
    return this.container.lookup("service:composer")?.visible;
  }

  get router() {
    return this.container.lookup("router:main");
  }

  get routerService() {
    return this.container.lookup("service:router");
  }

  get appEvents() {
    return this.container.lookup("service:app-events");
  }

  controllerFor(name) {
    return this.container.lookup("controller:" + name);
  }

  /**
    Be wary of looking up the router. In this case, we have links in our
    HTML, say form compiled markdown posts, that need to be routed.
  **/
  handleURL(path, opts) {
    opts = opts || {};

    if (opts.replaceURL) {
      this.replaceState(path);
    }

    const split = path.split("#");
    let elementId;

    if (split.length === 2) {
      path = split[0];
      elementId = split[1];
    }

    // Remove multiple consecutive slashes from path. Same as Ember does on initial page load:
    // https://github.com/emberjs/ember.js/blob/8abcd000ee/packages/%40ember/routing/history-location.ts#L146
    path = path.replaceAll(/\/\/+/g, "/");

    const transition = this.routerService.transitionTo(path);

    transition._discourse_intercepted = true;
    transition._discourse_anchor = elementId;
    transition._discourse_original_url = path;

    const promise = transition.promise || transition;
    return promise.then(() => this.jumpToElement(elementId));
  }

  jumpToElement(elementId) {
    if (_jumpScheduled || isEmpty(elementId)) {
      return;
    }

    const selector = `#main #${elementId}, a[name=${elementId}]`;
    _jumpScheduled = true;

    schedule("afterRender", function () {
      if (lockOn) {
        lockOn.clearLock();
      }

      lockOn = new LockOn(selector, {
        finished() {
          _jumpScheduled = false;
          lockOn = null;
        },
      });
      lockOn.lock();
    });
  }
}

let _urlInstance = DiscourseURL.create();

export function setURLContainer(container) {
  _urlInstance.container = container;
  setOwner(_urlInstance, container);
}

export function prefixProtocol(url) {
  return !url.includes("://") && !url.startsWith("mailto:")
    ? "https://" + url
    : url;
}

export function getCategoryAndTagUrl(category, subcategories, tag) {
  let url;

  if (category) {
    url = category.path;
    if (category.default_list_filter === "none" && subcategories) {
      if (subcategories) {
        url += "/all";
      } else {
        url += "/none";
      }
    } else if (!subcategories) {
      url += "/none";
    }
  }

  if (tag) {
    url = url
      ? "/tags" + url + "/" + tag.toLowerCase()
      : "/tag/" + tag.toLowerCase();
  }

  return getURL(url || "/");
}

export function getEditCategoryUrl(category, subcategories, tab) {
  let url = `/c/${Category.slugFor(category)}/edit`;

  if (tab) {
    url += `/${tab}`;
  }
  return getURL(url);
}

export function getCanonicalUrl(absoluteUrl) {
  const canonicalUrl = new URL(absoluteUrl);
  canonicalUrl.pathname = canonicalUrl.pathname.replace(
    TRAILING_SLASH_REGEX,
    ""
  );

  const allowedSearchParams = new URLSearchParams();
  for (const [key, value] of canonicalUrl.searchParams) {
    if (ALLOWED_CANONICAL_PARAMS.includes(key)) {
      allowedSearchParams.append(key, value);
    }
  }
  canonicalUrl.search = allowedSearchParams.toString();

  return canonicalUrl.toString();
}

export default _urlInstance;
