import { applyDecorators, createWidget } from "discourse/widgets/widget";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { avatarImg } from "discourse/widgets/post";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import renderTags from "discourse/lib/render-tags";
import { topicFeaturedLinkNode } from "discourse/lib/render-topic-featured-link";

createWidget("topic-header-participant", {
  tagName: "span",

  buildClasses(attrs) {
    return `trigger-${attrs.type}-card`;
  },

  html(attrs) {
    const { user, group } = attrs;
    let content, url;

    if (attrs.type === "user") {
      content = avatarImg("tiny", {
        template: user.avatar_template,
        username: user.username,
      });
      url = user.get("path");
    } else {
      content = [iconNode("users")];
      url = getURL(`/g/${group.name}`);
      content.push(h("span", group.name));
    }

    return h(
      "a.icon",
      {
        attributes: {
          href: url,
          "data-auto-route": true,
          title: attrs.username,
        },
      },
      content
    );
  },

  click(e) {
    this.appEvents.trigger(
      `topic-header:trigger-${this.attrs.type}-card`,
      this.attrs.username,
      e.target
    );
    e.preventDefault();
  },
});

export default createWidget("header-topic-info", {
  tagName: "div.extra-info-wrapper",
  contents: null,
  title: null,

  buildClasses(attrs, state) {
    this.buildAttributes(attrs, state);
    return this.containerClassName();
  },

  buildFancyTitleClass() {
    const baseClass = ["topic-link"];
    const flatten = (array) => [].concat.apply([], array);
    const extraClass = flatten(
      applyDecorators(this, "fancyTitleClass", this.attrs, this.state)
    );
    return baseClass.concat(extraClass).filter(Boolean).join(" ");
  },

  buildAttributes(attrs, state) {
    const topic = attrs.topic;

    const heading = [];

    const showPM = !topic.get("is_warning") && topic.get("isPrivateMessage");
    if (showPM) {
      const href = this.currentUser && this.currentUser.pmPath(topic);
      if (href) {
        heading.push(
          h(
            "a.private-message-glyph-wrapper",
            {
              attributes: { href, "aria-label": I18n.t("user.messages.inbox") },
            },
            iconNode("envelope", { class: "private-message-glyph" })
          )
        );
      }
    }
    const loaded = topic.get("details.loaded");
    const fancyTitle = topic.get("fancyTitle");
    const href = topic.get("url");

    if (fancyTitle && href) {
      heading.push(this.attach("topic-status", attrs));

      const titleHTML = new RawHtml({ html: `<span>${fancyTitle}</span>` });
      heading.push(
        this.attach("link", {
          className: this.buildFancyTitleClass(),
          action: "jumpToTopPost",
          href,
          attributes: { "data-topic-id": topic.get("id") },
          contents: () => titleHTML,
        })
      );
    }

    this.headerElements = [h("h1.header-title", heading)];
    const category = topic.get("category");

    if (loaded || category) {
      if (
        category &&
        (!category.isUncategorizedCategory ||
          !this.siteSettings.suppress_uncategorized_badge)
      ) {
        const parentCategory = category.get("parentCategory");
        const categories = [];
        if (parentCategory) {
          if (
            this.siteSettings.max_category_nesting > 2 &&
            !this.site.mobileView
          ) {
            const grandParentCategory = parentCategory.get("parentCategory");
            if (grandParentCategory) {
              categories.push(
                this.attach("category-link", { category: grandParentCategory })
              );
            }
          }

          categories.push(
            this.attach("category-link", { category: parentCategory })
          );
        }
        categories.push(this.attach("category-link", { category }));

        this.headerElements.push(h("div.categories-wrapper", categories));
      }

      let extra = [];
      const tags = renderTags(topic);
      if (tags && tags.length > 0) {
        extra.push(new RawHtml({ html: tags }));
      }

      if (showPM) {
        const maxHeaderParticipants = extra.length > 0 ? 5 : 10;
        const participants = [];
        const topicDetails = topic.get("details");
        const totalParticipants =
          topicDetails.allowed_users.length +
          topicDetails.allowed_groups.length;

        topicDetails.allowed_users.some((user) => {
          if (participants.length >= maxHeaderParticipants) {
            return true;
          }

          participants.push(
            this.attach("topic-header-participant", {
              type: "user",
              user,
              username: user.username,
            })
          );
        });

        topicDetails.allowed_groups.some((group) => {
          if (participants.length >= maxHeaderParticipants) {
            return true;
          }

          participants.push(
            this.attach("topic-header-participant", {
              type: "group",
              group,
              username: group.name,
            })
          );
        });

        if (totalParticipants > maxHeaderParticipants) {
          const remaining = totalParticipants - maxHeaderParticipants;
          participants.push(
            this.attach("link", {
              className: "more-participants",
              action: "jumpToTopPost",
              href,
              attributes: { "data-topic-id": topic.get("id") },
              contents: () => `+${remaining}`,
            })
          );
        }

        extra.push(h("div.topic-header-participants", participants));
      }

      extra = extra.concat(applyDecorators(this, "after-tags", attrs, state));

      if (this.siteSettings.topic_featured_link_enabled) {
        const featured = topicFeaturedLinkNode(attrs.topic);
        if (featured) {
          extra.push(featured);
        }
      }
      if (extra.length) {
        this.headerElements.push(h("div.topic-header-extra", extra));
      }
    }
    this.contents = h("div.title-wrapper", this.headerElements);
  },

  html() {
    return h(
      "div.extra-info",
      { className: this.containerClassName() },
      this.contents
    );
  },

  containerClassName() {
    return this.headerElements.length > 1 ? "two-rows" : "";
  },

  jumpToTopPost() {
    const topic = this.attrs.topic;
    if (topic) {
      DiscourseURL.routeTo(topic.get("firstPostUrl"), {
        keepFilter: true,
      });
    }
  },
});
