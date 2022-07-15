import GlimmerComponent from "discourse/components/glimmer";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";

import Docking from "discourse/mixins/docking";
import { headerOffset } from "discourse/lib/offset-calculator";
import { observes } from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";
import RawHtml from "discourse/widgets/raw-html";
import renderTags from "discourse/lib/render-tags";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

export default class TopicTimeline extends GlimmerComponent {
  @tracked prevEvent;

  mobileView = this.site.mobileView;
  intersectionObserver = null;
  dockAt = null;
  dockBottom = null;
  adminTools = optionalService();
  position = null;
  excerpt = null;

  constructor() {
    super(...arguments);
  }

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

    return result;
  }

  @action
  updateEnteredIndex(prevEvent) {
    this.prevEvent = prevEvent;
    if (prevEvent) {
      this.enteredIndex = prevEvent.postIndex - 1;
    }
  }

  @observes("topic.highest_post_number", "loading")
  newPostAdded() {
    // not sure if this is the play
    Docking.queueDockCheck();
  }

  @observes("topic.details.notification_level")
  updateNotificationLevel() {
    // update value here
  }

  @bind
  dockCheck() {
    const timeline = this.element.querySelector(".timeline-container");
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;

    const prev = this.args.dockAt;
    const posTop = headerOffset() + window.pageYOffset;
    const pos = posTop + timelineHeight;

    this.args.dockBottom = false;
    if (posTop < this.topicTop) {
      this.args.dockAt = parseInt(this.topicTop, 10);
    } else if (pos > this.topicBottom) {
      this.args.dockAt = parseInt(this.topicBottom - timelineHeight, 10);
      this.args.dockBottom = true;
      if (this.dockAt < 0) {
        this.dockAt = 0;
      }
    } else {
      this.dockAt = null;
      this.fastDockAt = parseInt(this.topicBottom - timelineHeight, 10);
    }

    if (this.dockAt !== prev) {
      this.queueRerender();
    }
  }

  didInsert() {
    this.dispatch(
      "topic:current-post-scrolled",
      () => `timeline-scrollarea-${this.args.topic.id}`
    );
    this.dispatch("topic:toggle-actions", "topic-admin-menu-button");
    if (!this.site.mobileView) {
      this.appEvents.on("composer:opened", this, this.queueRerender);
      this.appEvents.on("composer:resized", this, this.queueRerender);
      this.appEvents.on("composer:closed", this, this.queueRerender);
      if ("IntersectionObserver" in window) {
        this.intersectionObserver = new IntersectionObserver((entries) => {
          for (const entry of entries) {
            const bounds = entry.boundingClientRect;

            if (entry.target.id === "topic-bottom") {
              this.set("topicBottom", bounds.y + window.scrollY);
            } else {
              this.set("topicTop", bounds.y + window.scrollY);
            }
          }
        });

        const elements = [
          document.querySelector(".container.posts"),
          document.querySelector("#topic-bottom"),
        ];

        for (let i = 0; i < elements.length; i++) {
          this.intersectionObserver.observe(elements[i]);
        }
      }
    }
  }

  willDestroy() {
    //if (!this.site.mobileView) {
    // this.appEvents.off("composer:opened", this, this.queueRerender);
    // this.appEvents.off("composer:resized", this, this.queueRerender);
    // this.appEvents.off("composer:closed", this, this.queueRerender);
    // if ("IntersectionObserver" in window) {
    //  this.intersectionObserver?.disconnect();
    // this.intersectionObserver = null;
    //}
    //}
  }
}
