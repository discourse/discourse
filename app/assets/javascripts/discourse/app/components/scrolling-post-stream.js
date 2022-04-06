import { cloak, uncloak } from "discourse/widgets/post-stream";
import { schedule, scheduleOnce } from "@ember/runloop";
import DiscourseURL from "discourse/lib/url";
import MountWidget from "discourse/components/mount-widget";
import discourseDebounce from "discourse-common/lib/debounce";
import { isWorkaroundActive } from "discourse/lib/safari-hacks";
import offsetCalculator from "discourse/lib/offset-calculator";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import domUtils from "discourse-common/utils/dom-utils";

const DEBOUNCE_DELAY = 50;

function findTopView(posts, viewportTop, postsWrapperTop, min, max) {
  if (max < min) {
    return min;
  }

  while (max > min) {
    const mid = Math.floor((min + max) / 2);
    const post = posts.item(mid);
    const viewBottom =
      domUtils.offset(post).top - postsWrapperTop + post.clientHeight;

    if (viewBottom > viewportTop) {
      max = mid - 1;
    } else {
      min = mid + 1;
    }
  }

  return min;
}

export default MountWidget.extend({
  screenTrack: service(),
  widget: "post-stream",
  _topVisible: null,
  _bottomVisible: null,
  _currentPost: null,
  _currentVisible: null,
  _currentPercent: null,

  buildArgs() {
    return this.getProperties(
      "posts",
      "canCreatePost",
      "filteredPostsCount",
      "multiSelect",
      "gaps",
      "selectedQuery",
      "selectedPostsCount",
      "searchService",
      "showReadIndicator",
      "streamFilters",
      "lastReadPostNumber",
      "highestPostNumber"
    );
  },

  beforePatch() {
    this.prevHeight = document.body.clientHeight;
    this.prevScrollTop = document.body.scrollTop;
  },

  afterPatch() {
    const height = document.body.clientHeight;

    // This hack is for when swapping out many cloaked views at once
    // when using keyboard navigation. It could suddenly move the scroll
    if (
      this.prevHeight === height &&
      document.body.scrollTop !== this.prevScrollTop
    ) {
      document.body.scroll({ left: 0, top: this.prevScrollTop });
    }
  },

  scrolled() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    if (
      isWorkaroundActive() ||
      document.webkitFullscreenElement ||
      document.fullscreenElement
    ) {
      return;
    }

    // We use this because watching videos fullscreen in Chrome was super buggy
    // otherwise. Thanks to arrendek from q23 for the technique.
    const topLeftCornerElement = document.elementFromPoint(0, 0);
    if (
      topLeftCornerElement &&
      topLeftCornerElement.tagName.toUpperCase() === "IFRAME"
    ) {
      return;
    }

    const windowHeight = window.innerHeight;
    const slack = Math.round(windowHeight * 5);
    const onscreen = [];
    const nearby = [];
    const windowTop = document.documentElement.scrollTop;
    const postsWrapperTop = domUtils.offset(
      document.querySelector(".posts-wrapper")
    ).top;
    const postsNodes = this.element.querySelectorAll(
      ".onscreen-post, .cloaked-post"
    );

    const viewportTop = windowTop - slack;
    const topView = findTopView(
      postsNodes,
      viewportTop,
      postsWrapperTop,
      0,
      postsNodes.length - 1
    );

    let windowBottom = windowTop + windowHeight;
    let viewportBottom = windowBottom + slack;
    const bodyHeight = document.body.clientHeight;
    if (windowBottom > bodyHeight) {
      windowBottom = bodyHeight;
    }
    if (viewportBottom > bodyHeight) {
      viewportBottom = bodyHeight;
    }

    let currentPost = null;
    let percent = null;

    const offset = offsetCalculator();
    const topCheck = Math.ceil(windowTop + offset + 5);

    // uncomment to debug the eyeline
    /*
    let $eyeline = $('.debug-eyeline');
    if ($eyeline.length === 0) {
      $('body').prepend('<div class="debug-eyeline"></div>');
      $eyeline = $('.debug-eyeline');
    }
    $eyeline.css({ height: '5px', width: '100%', backgroundColor: 'blue', position: 'absolute', top: `${topCheck}px`, zIndex: 999999 });
    */

    let allAbove = true;
    let bottomView = topView;
    let lastBottom = 0;
    while (bottomView < postsNodes.length) {
      const post = postsNodes.item(bottomView);

      if (!post) {
        break;
      }

      const viewTop = domUtils.offset(post).top;
      const postHeight = post.clientHeight;
      const viewBottom = Math.ceil(viewTop + postHeight);

      allAbove = allAbove && viewTop < topCheck;

      if (viewTop > viewportBottom) {
        break;
      }

      if (viewBottom >= windowTop && viewTop <= windowBottom) {
        onscreen.push(bottomView);
      }

      if (
        currentPost === null &&
        ((viewTop <= topCheck && viewBottom >= topCheck) ||
          (lastBottom <= topCheck && viewTop >= topCheck))
      ) {
        percent = (topCheck - viewTop) / postHeight;
        currentPost = bottomView;
      }

      lastBottom = viewBottom;
      nearby.push(bottomView);
      bottomView++;
    }

    if (allAbove) {
      if (percent === null) {
        percent = 1.0;
      }
      if (currentPost === null) {
        currentPost = bottomView - 1;
      }
    }

    const posts = this.posts;
    const refresh = (cb) => this.queueRerender(cb);
    if (onscreen.length) {
      const first = posts.objectAt(onscreen[0]);
      if (this._topVisible !== first) {
        this._topVisible = first;
        const elem = postsNodes.item(onscreen[0]);
        const elemId = elem.id;
        const elemPos = domUtils.position(elem);
        const distToElement = elemPos
          ? document.body.scrollTop - elemPos.top
          : 0;

        const topRefresh = () => {
          refresh(() => {
            const refreshedElem = document.getElementById(elemId);

            // Quickly going back might mean the element is destroyed
            const position = domUtils.position(refreshedElem);
            if (position && position.top) {
              let whereY = position.top + distToElement;
              document.documentElement.scroll({ top: whereY, left: 0 });

              // This seems weird, but somewhat infrequently a rerender
              // will cause the browser to scroll to the top of the document
              // in Chrome. This makes sure the scroll works correctly if that
              // happens.
              schedule("afterRender", () => {
                document.documentElement.scroll({ top: whereY, left: 0 });
              });
            }
          });
        };
        this.topVisibleChanged({
          post: first,
          refresh: topRefresh,
        });
      }

      const last = posts.objectAt(onscreen[onscreen.length - 1]);
      if (this._bottomVisible !== last) {
        this._bottomVisible = last;
        this.bottomVisibleChanged({ post: last, refresh });
      }

      const changedPost = this._currentPost !== currentPost;
      if (changedPost) {
        this._currentPost = currentPost;
        const post = posts.objectAt(currentPost);
        this.currentPostChanged({ post });
      }

      if (percent !== null) {
        percent = Math.max(0.0, Math.min(1.0, percent));

        if (changedPost || this._currentPercent !== percent) {
          this._currentPercent = percent;
          this.currentPostScrolled({ percent });
        }
      }
    } else {
      this._topVisible = null;
      this._bottomVisible = null;
      this._currentPost = null;
      this._currentPercent = null;
    }

    const onscreenPostNumbers = [];
    const readPostNumbers = [];

    const prev = this._previouslyNearby;
    const newPrev = {};
    nearby.forEach((idx) => {
      const post = posts.objectAt(idx);
      const postNumber = post.post_number;

      delete prev[postNumber];

      if (onscreen.indexOf(idx) !== -1) {
        onscreenPostNumbers.push(postNumber);
        if (post.read) {
          readPostNumbers.push(postNumber);
        }
      }
      newPrev[postNumber] = post;
      uncloak(post, this);
    });

    Object.values(prev).forEach((node) => cloak(node, this));

    this._previouslyNearby = newPrev;
    this.screenTrack.setOnscreen(onscreenPostNumbers, readPostNumbers);
  },

  _scrollTriggered() {
    scheduleOnce("afterRender", this, this.scrolled);
  },

  _posted(staged) {
    this.queueRerender(() => {
      if (staged) {
        const postNumber = staged.post_number;
        DiscourseURL.jumpToPost(postNumber, { skipIfOnScreen: true });
      }
    });
  },

  _refresh(args) {
    if (args) {
      if (args.id) {
        this.dirtyKeys.keyDirty(`post-${args.id}`);

        if (args.refreshLikes) {
          this.dirtyKeys.keyDirty(`post-menu-${args.id}`, {
            onRefresh: "refreshLikes",
          });
        }

        if (args.refreshReaders) {
          this.dirtyKeys.keyDirty(`post-menu-${args.id}`, {
            onRefresh: "refreshReaders",
          });
        }
      } else if (args.force) {
        this.dirtyKeys.forceAll();
      }
    }
    this.queueRerender();
  },

  @bind
  _debouncedScroll() {
    discourseDebounce(this, this._scrollTriggered, DEBOUNCE_DELAY);
  },

  didInsertElement() {
    this._super(...arguments);
    this._previouslyNearby = {};

    this.appEvents.on("post-stream:refresh", this, "_debouncedScroll");
    const opts = {
      passive: true,
    };
    document.addEventListener("touchmove", this._debouncedScroll, opts);
    window.addEventListener("scroll", this._debouncedScroll, opts);
    this._scrollTriggered();

    this.appEvents.on("post-stream:posted", this, "_posted");

    this.element.addEventListener(
      "mouseenter",
      this._handleWidgetButtonHoverState,
      true
    );

    this.element.addEventListener(
      "mouseleave",
      this._removeWidgetButtonHoverState,
      true
    );

    this.appEvents.on("post-stream:refresh", this, "_refresh");

    // restore scroll position on browsers with aggressive BFCaches (like Safari)
    window.onpageshow = function (event) {
      if (event.persisted) {
        DiscourseURL.routeTo(this.location.pathname);
      }
    };
  },

  willDestroyElement() {
    this._super(...arguments);

    document.removeEventListener("touchmove", this._debouncedScroll);
    window.removeEventListener("scroll", this._debouncedScroll);
    this.appEvents.off("post-stream:refresh", this, "_debouncedScroll");
    this.element.removeEventListener(
      "mouseenter",
      this._handleWidgetButtonHoverState
    );
    this.element.removeEventListener(
      "mouseleave",
      this._removeWidgetButtonHoverState
    );
    this.appEvents.off("post-stream:refresh", this, "_refresh");
    this.appEvents.off("post-stream:posted", this, "_posted");
  },

  _handleWidgetButtonHoverState(event) {
    if (event.target.classList.contains("widget-button")) {
      document
        .querySelectorAll("button.widget-button")
        .forEach((widgetButton) => {
          widgetButton.classList.remove("d-hover");
        });
      event.target.classList.add("d-hover");
    }
  },

  _removeWidgetButtonHoverState() {
    document.querySelectorAll("button.widget-button").forEach((button) => {
      button.classList.remove("d-hover");
    });
  },
});
