import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { actionDescriptionHtml } from "discourse/widgets/post-small-action";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { later } from "@ember/runloop";
import { relativeAge } from "discourse/lib/formatter";
import renderTags from "discourse/lib/render-tags";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

const SCROLLER_HEIGHT = 50;
const LAST_READ_HEIGHT = 20;
const MIN_SCROLLAREA_HEIGHT = 170;
const MAX_SCROLLAREA_HEIGHT = 300;

export default class TopicTimelineContainer extends GlimmerComponent {
  buildKey = (attrs) => `topic-timeline-area-${attrs.topic.id}`;

  get class() {
    let classes = [];
    if (this.args.fullscreen) {
      if (this.addShowClass) {
        classes.push("timeline-fullscreen show");
      } else {
        classes.push("timeline-fullscreen");
      }
    }

    if (this.args.dockAt) {
      classes.push("timeline-docked");
      if (this.args.dockBottom) {
        classes.push("timeline-docked-bottom");
      }
    }

    return classes.join(" ");
  }

  get addShowClass() {
    this.args.fullscreen && !this.args.addShowClass ? true : false;
  }

  constructor() {
    super(...arguments);
  }

  @bind
  scrollareaHeight() {
    const composerHeight =
        document.getElementById("reply-control").offsetHeight || 0,
      headerHeight =
        document.querySelectorAll(".d-header")[0].offsetHeight || 0;

    // scrollarea takes up about half of the timeline's height
    const availableHeight =
      (window.innerHeight - composerHeight - headerHeight) / 2;

    return Math.max(
      MIN_SCROLLAREA_HEIGHT,
      Math.min(availableHeight, MAX_SCROLLAREA_HEIGHT)
    );
  }

  @bind
  scrollareaRemaining() {
    return scrollareaHeight() - SCROLLER_HEIGHT;
  }

  @bind
  clamp(p, min = 0.0, max = 1.0) {
    return Math.max(Math.min(p, max), min);
  }

  @bind
  attachBackButton(widget) {
    return widget.attach("button", {
      className: "btn-primary btn-small back-button",
      label: "topic.timeline.back",
      title: "topic.timeline.back_description",
      action: "goBack",
    });
  }
  @bind
  timelineDate(date) {
    const fmt =
      date.getFullYear() === new Date().getFullYear()
        ? "long_no_year_no_time"
        : "timeline_date";
    return moment(date).format(I18n.t(`dates.${fmt}`));
  }

  @bind
  defaultState() {
    return { position: null, excerpt: null };
  }

  @bind
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
      stream.excerpt(scrollPosition - 1).then((info) => {
        if (info && this.state.position === scrollPosition) {
          let excerpt = "";

          if (info.username) {
            excerpt = "<span class='username'>" + info.username + ":</span> ";
          }

          if (info.excerpt) {
            this.state.excerpt = excerpt + info.excerpt;
          } else if (info.action_code) {
            this.state.excerpt = `${excerpt} ${actionDescriptionHtml(
              info.action_code,
              info.created_at,
              info.username
            )}`;
          }

          this.scheduleRerender();
        }
      });
    }, 50);
  }

  @bind
  html(attrs) {
    const { topic } = attrs;
    const createdAt = new Date(topic.created_at);
    const { currentUser } = this;
    const { tagging_enabled, topic_featured_link_enabled } = this.siteSettings;

    attrs["currentUser"] = currentUser;

    let result = [];

    if (attrs.fullScreen) {
      let titleHTML = "";
      if (attrs.mobileView) {
        titleHTML = new RawHtml({
          html: `<span>${topic.get("fancyTitle")}</span>`,
        });
      }

      let elems = [
        h(
          "h2",
          this.attach("link", {
            contents: () => titleHTML,
            className: "fancy-title",
            action: "jumpTop",
          })
        ),
      ];

      // duplicate of the {{topic-category}} component
      let category = [];

      if (!topic.get("isPrivateMessage")) {
        if (topic.category.parentCategory) {
          category.push(
            this.attach("category-link", {
              category: topic.category.parentCategory,
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
            html: renderTags(topic, { mode: "list" }),
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
            html: `<div class='post-excerpt'>${this.state.excerpt}</div>`,
          })
        );
      }

      result.push(h("div.title", elems));
    }

    result.push(this.attach("timeline-controls", attrs));

    let displayTimeLineScrollArea = true;
    if (!attrs.mobileView) {
      const streamLength = attrs.topic.get("postStream.stream.length");

      if (streamLength === 1) {
        const postsWrapper = document.querySelector(".posts-wrapper");
        if (postsWrapper && postsWrapper.offsetHeight < 1000) {
          displayTimeLineScrollArea = false;
        }
      }
    }

    if (displayTimeLineScrollArea) {
      const bottomAge = relativeAge(
        new Date(topic.last_posted_at || topic.created_at),
        {
          addAgo: true,
          defaultFormat: timelineDate,
        }
      );
      const scroller = [
        h(
          "div.timeline-date-wrapper",
          this.attach("link", {
            className: "start-date",
            rawLabel: timelineDate(createdAt),
            action: "jumpTop",
          })
        ),
        this.attach("timeline-scrollarea", attrs),
        h(
          "div.timeline-date-wrapper",
          this.attach("link", {
            className: "now-date",
            rawLabel: bottomAge,
            action: "jumpBottom",
          })
        ),
      ];

      result.push(h("div.timeline-scrollarea-wrapper", scroller));
      result.push(this.attach("timeline-footer-controls", attrs));
    }

    return result;
  }
}
