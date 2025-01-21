import { schedule, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import MountWidget from "discourse/components/mount-widget";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import domUtils from "discourse/lib/dom-utils";
import offsetCalculator from "discourse/lib/offset-calculator";
import DiscourseURL from "discourse/lib/url";
import { cloak, uncloak } from "discourse/widgets/post-stream";

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

export default class ScrollingPostStream extends MountWidget {
  @service screenTrack;

  widget = "post-stream";
  _topVisible = null;
  _bottomVisible = null;
  _currentPostObj = null;
  _currentVisible = null;
  _currentPercent = null;

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
  }

  scrolled() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    if (document.webkitFullscreenElement || document.fullscreenElement) {
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
    const windowTop = document.scrollingElement.scrollTop;
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
        const elemId = postsNodes.item(onscreen[0]).id;

        const topRefresh = () => {
          refresh(() => {
            const refreshedElem = document.getElementById(elemId);

            if (!refreshedElem) {
              return;
            }

            // The getOffsetTop function calculates the total offset distance of
            // an element from the top of the document. Unlike element.offsetTop
            // which only returns the offset relative to its nearest positioned
            // ancestor, this function recursively accumulates the offsetTop
            // of an element and all of its offset parents (ancestors).
            // This ensures the total distance is measured from the very top of
            // the document, accounting for any nested elements and their
            // respective offsets.
            const getOffsetTop = (element) => {
              if (!element) {
                return 0;
              }
              return element.offsetTop + getOffsetTop(element.offsetParent);
            };

            window.scrollTo({
              top: getOffsetTop(refreshedElem) - offsetCalculator(),
            });

            // This seems weird, but somewhat infrequently a rerender
            // will cause the browser to scroll to the top of the document
            // in Chrome. This makes sure the scroll works correctly if that
            // happens.
            schedule("afterRender", () => {
              window.scrollTo({
                top: getOffsetTop(refreshedElem) - offsetCalculator(),
              });
            });
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

      const currentPostObj = posts.objectAt(currentPost);
      const changedPost = this._currentPostObj !== currentPostObj;
      if (changedPost) {
        this._currentPostObj = currentPostObj;
        this.currentPostChanged({ post: currentPostObj });
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
      this._currentPostObj = null;
      this._currentPercent = null;
    }

    const onscreenPostNumbers = new Set();
    const readPostNumbers = new Set();

    const newPrev = new Set();
    nearby.forEach((idx) => {
      const post = posts.objectAt(idx);

      this._previouslyNearby.delete(post.post_number);

      if (onscreen.includes(idx)) {
        onscreenPostNumbers.add(post.post_number);
        if (post.read) {
          readPostNumbers.add(post.post_number);
        }
      }

      newPrev.add(post.post_number, post);
      uncloak(post, this);
    });

    Object.values(this._previouslyNearby).forEach((node) => cloak(node, this));

    this._previouslyNearby = newPrev;
    this.screenTrack.setOnscreen(onscreenPostNumbers, readPostNumbers);
  }

  _scrollTriggered() {
    scheduleOnce("afterRender", this, this.scrolled);
  }

  _posted(staged) {
    this.queueRerender(() => {
      if (staged) {
        const postNumber = staged.post_number;
        DiscourseURL.jumpToPost(postNumber, { skipIfOnScreen: true });
      }
    });
  }

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
    this._scrollTriggered();
  }

  @bind
  _debouncedScroll() {
    discourseDebounce(this, this._scrollTriggered, DEBOUNCE_DELAY);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this._previouslyNearby = new Set();

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
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

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
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    this._refresh({ force: true });
  }

  _handleWidgetButtonHoverState(event) {
    if (event.target.classList.contains("widget-button")) {
      document
        .querySelectorAll("button.widget-button")
        .forEach((widgetButton) => {
          widgetButton.classList.remove("d-hover");
        });
      event.target.classList.add("d-hover");
    }
  }

  _removeWidgetButtonHoverState() {
    document.querySelectorAll("button.widget-button").forEach((button) => {
      button.classList.remove("d-hover");
    });
  }
}
