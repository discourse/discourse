import { later } from "@ember/runloop";
import { createWidget } from "discourse/widgets/widget";
import ComponentConnector from "discourse/widgets/component-connector";
import { h } from "virtual-dom";
import { relativeAge } from "discourse/lib/formatter";
import { iconNode } from "discourse-common/lib/icon-library";
import RawHtml from "discourse/widgets/raw-html";
import renderTags from "discourse/lib/render-tags";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

const SCROLLER_HEIGHT = 50;
const LAST_READ_HEIGHT = 20;
const MIN_SCROLLAREA_HEIGHT = 170;
const MAX_SCROLLAREA_HEIGHT = 300;

function scrollareaHeight() {
  const composerHeight =
      document.getElementById("reply-control").offsetHeight || 0,
    headerHeight = document.querySelectorAll(".d-header")[0].offsetHeight || 0;

  // scrollarea takes up about half of the timeline's height
  const availableHeight =
    (window.innerHeight - composerHeight - headerHeight) / 2;

  return Math.max(
    MIN_SCROLLAREA_HEIGHT,
    Math.min(availableHeight, MAX_SCROLLAREA_HEIGHT)
  );
}

function scrollareaRemaining() {
  return scrollareaHeight() - SCROLLER_HEIGHT;
}

function clamp(p, min = 0.0, max = 1.0) {
  return Math.max(Math.min(p, max), min);
}

function attachBackButton(widget) {
  return widget.attach("button", {
    className: "btn-primary btn-small back-button",
    label: "topic.timeline.back",
    title: "topic.timeline.back_description",
    action: "goBack"
  });
}

createWidget("timeline-last-read", {
  tagName: "div.timeline-last-read",

  buildAttributes(attrs) {
    const bottom = scrollareaHeight() - LAST_READ_HEIGHT / 2;
    const top = attrs.top > bottom ? bottom : attrs.top;
    return { style: `height: ${LAST_READ_HEIGHT}px; top: ${top}px` };
  },

  html(attrs) {
    const result = [iconNode("minus", { class: "progress" })];
    if (attrs.showButton) {
      result.push(attachBackButton(this));
    }

    return result;
  }
});

function timelineDate(date) {
  const fmt =
    date.getFullYear() === new Date().getFullYear()
      ? "long_no_year_no_time"
      : "timeline_date";
  return moment(date).format(I18n.t(`dates.${fmt}`));
}

createWidget("timeline-scroller", {
  tagName: "div.timeline-scroller",
  buildKey: () => `timeline-scroller`,

  defaultState() {
    return { dragging: false };
  },

  buildAttributes() {
    return { style: `height: ${SCROLLER_HEIGHT}px` };
  },

  html(attrs, state) {
    const { current, total, date } = attrs;

    const contents = [
      h(
        "div.timeline-replies",
        I18n.t(`topic.timeline.replies_short`, { current, total })
      )
    ];

    if (date) {
      contents.push(h("div.timeline-ago", timelineDate(date)));
    }

    if (attrs.showDockedButton && !state.dragging) {
      contents.push(attachBackButton(this));
    }
    let result = [
      h("div.timeline-handle"),
      h("div.timeline-scroller-content", contents)
    ];

    if (attrs.fullScreen) {
      result = [result[1], result[0]];
    }

    return result;
  },

  drag(e) {
    this.state.dragging = true;
    this.sendWidgetAction("updatePercentage", e.pageY);
  },

  dragEnd(e) {
    this.state.dragging = false;
    if ($(e.target).is("button")) {
      this.sendWidgetAction("goBack");
    } else {
      this.sendWidgetAction("commit");
    }
  }
});

createWidget("timeline-padding", {
  tagName: "div.timeline-padding",
  buildAttributes(attrs) {
    return { style: `height: ${attrs.height}px` };
  },

  click(e) {
    this.sendWidgetAction("updatePercentage", e.pageY);
    this.sendWidgetAction("commit");
  }
});

createWidget("timeline-scrollarea", {
  tagName: "div.timeline-scrollarea",
  buildKey: () => `timeline-scrollarea`,

  buildAttributes() {
    return { style: `height: ${scrollareaHeight()}px` };
  },

  defaultState(attrs) {
    return {
      percentage: this._percentFor(attrs.topic, attrs.enteredIndex + 1),
      scrolledPost: 1
    };
  },

  position() {
    const { attrs } = this;
    const percentage = this.state.percentage;
    const topic = attrs.topic;
    const postStream = topic.get("postStream");
    const total = postStream.get("filteredPostsCount");

    const scrollPosition = clamp(Math.floor(total * percentage), 0, total) + 1;
    const current = clamp(scrollPosition, 1, total);

    const daysAgo = postStream.closestDaysAgoFor(current);
    let date;

    if (daysAgo === undefined) {
      const post = postStream
        .get("posts")
        .findBy("id", postStream.get("stream")[current]);

      if (post) date = new Date(post.get("created_at"));
    } else if (daysAgo !== null) {
      date = new Date();
      date.setDate(date.getDate() - daysAgo || 0);
    } else {
      date = null;
    }

    const result = {
      current,
      scrollPosition,
      total,
      date,
      lastRead: null,
      lastReadPercentage: null
    };

    const lastReadId = topic.last_read_post_id;
    const lastReadNumber = topic.last_read_post_number;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.get("stream").indexOf(lastReadId) + 1;
      result.lastRead = idx;
      result.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.state.position !== result.scrollPosition) {
      this.state.position = result.scrollPosition;
      this.sendWidgetAction("updatePosition", current);
    }

    return result;
  },

  html(attrs, state) {
    const position = this.position();

    state.scrolledPost = position.current;
    const percentage = state.percentage;
    if (percentage === null) {
      return;
    }

    const before = scrollareaRemaining() * percentage;
    const after = scrollareaHeight() - before - SCROLLER_HEIGHT;

    let showButton = false;
    const hasBackPosition =
      position.lastRead > 3 &&
      Math.abs(position.lastRead - position.current) > 3 &&
      Math.abs(position.lastRead - position.total) > 1 &&
      position.lastRead &&
      position.lastRead !== position.total;

    if (hasBackPosition) {
      const lastReadTop = Math.round(
        position.lastReadPercentage * scrollareaHeight()
      );
      showButton =
        before + SCROLLER_HEIGHT - 5 < lastReadTop || before > lastReadTop + 25;
    }

    const result = [
      this.attach("timeline-padding", { height: before }),
      this.attach(
        "timeline-scroller",
        _.merge(position, {
          showDockedButton: !attrs.mobileView && hasBackPosition && !showButton,
          fullScreen: attrs.fullScreen
        })
      ),
      this.attach("timeline-padding", { height: after })
    ];

    if (hasBackPosition) {
      const lastReadTop = Math.round(
        position.lastReadPercentage * scrollareaHeight()
      );
      result.push(
        this.attach("timeline-last-read", {
          top: lastReadTop,
          lastRead: position.lastRead,
          showButton
        })
      );
    }

    return result;
  },

  updatePercentage(y) {
    const $area = $(".timeline-scrollarea");
    const areaTop = $area.offset().top;

    const percentage = clamp(parseFloat(y - areaTop) / $area.height());

    this.state.percentage = percentage;
  },

  commit() {
    const position = this.position();
    this.state.scrolledPost = position.current;

    if (position.current === position.scrollPosition) {
      this.sendWidgetAction("jumpToIndex", position.current);
    } else {
      this.sendWidgetAction("jumpEnd");
    }
  },

  topicCurrentPostScrolled(event) {
    this.state.percentage = event.percent;
  },

  _percentFor(topic, postIndex) {
    const total = topic.get("postStream.filteredPostsCount");
    return clamp(parseFloat(postIndex - 1.0) / total);
  },

  goBack() {
    this.sendWidgetAction("jumpToIndex", this.position().lastRead);
  }
});

createWidget("topic-timeline-container", {
  tagName: "div.timeline-container",
  buildClasses(attrs) {
    if (attrs.fullScreen) {
      if (attrs.addShowClass) {
        return "timeline-fullscreen show";
      } else {
        return "timeline-fullscreen";
      }
    }
    if (attrs.dockAt) {
      const result = ["timeline-docked"];
      if (attrs.dockBottom) {
        result.push("timeline-docked-bottom");
      }
      return result.join(" ");
    }
  },

  buildAttributes(attrs) {
    if (attrs.top) {
      return { style: `top: ${attrs.top}px` };
    }
  },

  html(attrs) {
    return this.attach("topic-timeline", attrs);
  }
});

createWidget("timeline-controls", {
  tagName: "div.timeline-controls",

  html(attrs) {
    const controls = [];
    const { fullScreen, currentUser, topic } = attrs;

    if (!fullScreen && currentUser) {
      controls.push(
        this.attach("topic-admin-menu-button", {
          topic,
          addKeyboardTargetClass: true
        })
      );
    }

    return controls;
  }
});

createWidget("timeline-footer-controls", {
  tagName: "div.timeline-footer-controls",

  html(attrs) {
    const controls = [];
    const { currentUser, fullScreen, topic, notificationLevel } = attrs;

    if (currentUser && !fullScreen) {
      if (topic.get("details.can_create_post")) {
        controls.push(
          this.attach("button", {
            className: "btn-default create",
            icon: "reply",
            title: "topic.reply.help",
            action: "replyToPost"
          })
        );
      }
    }

    if (fullScreen) {
      controls.push(
        this.attach("button", {
          className: "jump-to-post",
          title: "topic.progress.jump_prompt_long",
          label: "topic.progress.jump_prompt",
          action: "jumpToPostPrompt"
        })
      );
    }

    if (currentUser) {
      controls.push(
        new ComponentConnector(
          this,
          "topic-notifications-options",
          {
            value: notificationLevel,
            topic,
            options: {
              showFullTitle: false,
              placement: "bottom-end"
            },
            onChange: newNotificationLevel => {
              if (newNotificationLevel !== notificationLevel) {
                topic.details.updateNotifications(newNotificationLevel);
              }
            }
          },
          ["value"]
        )
      );
    }

    return controls;
  }
});

export default createWidget("topic-timeline", {
  tagName: "div.topic-timeline",

  buildKey: () => "topic-timeline-area",

  defaultState() {
    return { position: null, excerpt: null };
  },

  updatePosition(scrollPosition) {
    if (!this.attrs.fullScreen) {
      return;
    }

    this.state.position = scrollPosition;
    this.state.excerpt = "";
    const stream = this.attrs.topic.get("postStream");

    // a little debounce to avoid flashing
    later(() => {
      if (!this.state.position === scrollPosition) {
        return;
      }

      // we have an off by one, stream is zero based,
      stream.excerpt(scrollPosition - 1).then(info => {
        if (info && this.state.position === scrollPosition) {
          let excerpt = "";

          if (info.username) {
            excerpt = "<span class='username'>" + info.username + ":</span> ";
          }

          this.state.excerpt = excerpt + info.excerpt;
          this.scheduleRerender();
        }
      });
    }, 50);
  },

  html(attrs) {
    const { topic } = attrs;
    const createdAt = new Date(topic.created_at);
    const stream = attrs.topic.get("postStream.stream");
    const { currentUser } = this;
    const { tagging_enabled, topic_featured_link_enabled } = this.siteSettings;

    attrs["currentUser"] = currentUser;

    let result = [];

    if (attrs.fullScreen) {
      let titleHTML = "";
      if (attrs.mobileView) {
        titleHTML = new RawHtml({
          html: `<span>${topic.get("fancyTitle")}</span>`
        });
      }

      let elems = [
        h(
          "h2",
          this.attach("link", {
            contents: () => titleHTML,
            className: "fancy-title",
            action: "jumpTop"
          })
        )
      ];

      // duplicate of the {{topic-category}} component
      let category = [];

      if (!topic.get("isPrivateMessage")) {
        if (topic.category.parentCategory) {
          category.push(
            this.attach("category-link", {
              category: topic.category.parentCategory
            })
          );
        }
        category.push(
          this.attach("category-link", { category: topic.category })
        );
      }

      const showTags = tagging_enabled && topic.tags && topic.tags.length > 0;

      if (showTags || topic_featured_link_enabled) {
        let extras = [];
        if (showTags) {
          const tagsHtml = new RawHtml({
            html: renderTags(topic, { mode: "list" })
          });
          extras.push(h("div.list-tags", tagsHtml));
        }
        if (topic_featured_link_enabled) {
          extras.push(new RawHtml({ html: renderTopicFeaturedLink(topic) }));
        }
        category.push(h("div.topic-header-extra", extras));
      }

      if (category.length > 0) {
        elems.push(h("div.topic-category", category));
      }

      if (this.state.excerpt) {
        elems.push(
          new RawHtml({
            html: `<div class='post-excerpt'>${this.state.excerpt}</div>`
          })
        );
      }

      result.push(h("div.title", elems));
    }

    result.push(this.attach("timeline-controls", attrs));
    const streamLength = stream.length;

    if (streamLength !== 0 && streamLength < 3) {
      const topicHeight = $("#topic").height();
      const windowHeight = $(window).height();
      if (topicHeight / windowHeight < 2.0) {
        return result;
      }
    }

    const bottomAge = relativeAge(new Date(topic.last_posted_at), {
      addAgo: true,
      defaultFormat: timelineDate
    });
    let scroller = [
      h(
        "div.timeline-date-wrapper",
        this.attach("link", {
          className: "start-date",
          rawLabel: timelineDate(createdAt),
          action: "jumpTop"
        })
      ),
      this.attach("timeline-scrollarea", attrs),
      h(
        "div.timeline-date-wrapper",
        this.attach("link", {
          className: "now-date",
          rawLabel: bottomAge,
          action: "jumpBottom"
        })
      )
    ];

    result.push(h("div.timeline-scrollarea-wrapper", scroller));
    result.push(this.attach("timeline-footer-controls", attrs));

    return result;
  }
});
