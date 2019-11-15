import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { avatarImg, avatarFor } from "discourse/widgets/post";
import { dateNode, numberNode } from "discourse/helpers/node";
import { replaceEmoji } from "discourse/widgets/emoji";

const LINKS_SHOWN = 5;

function renderParticipants(userFilters, participants) {
  if (!participants) {
    return;
  }

  userFilters = userFilters || [];
  return participants.map(p => {
    return this.attach("topic-participant", p, {
      state: { toggled: userFilters.includes(p.username) }
    });
  });
}

createWidget("topic-map-show-links", {
  tagName: "div.link-summary",
  html() {
    return h(
      "span",
      this.attach("button", {
        title: "topic_map.links_shown",
        icon: "chevron-down",
        action: "showLinks",
        className: "btn"
      })
    );
  },

  showLinks() {
    this.sendWidgetAction("showAllLinks");
  }
});

createWidget("topic-participant", {
  buildClasses(attrs) {
    if (attrs.primary_group_name) {
      return `group-${attrs.primary_group_name}`;
    }
  },

  html(attrs, state) {
    const linkContents = [
      avatarImg("medium", {
        username: attrs.username,
        template: attrs.avatar_template,
        name: attrs.name
      })
    ];

    if (attrs.post_count > 2) {
      linkContents.push(h("span.post-count", attrs.post_count.toString()));
    }

    if (attrs.primary_group_flair_url || attrs.primary_group_flair_bg_color) {
      linkContents.push(this.attach("avatar-flair", attrs));
    }

    return h(
      "a.poster.trigger-user-card",
      {
        className: state.toggled ? "toggled" : null,
        attributes: { title: attrs.username, "data-user-card": attrs.username }
      },
      linkContents
    );
  }
});

createWidget("topic-map-summary", {
  tagName: "section.map",

  buildClasses(attrs, state) {
    if (state.collapsed) {
      return "map-collapsed";
    }
  },

  html(attrs, state) {
    const contents = [];
    contents.push(
      h("li", [
        h(
          "h4",
          {
            attributes: { role: "presentation" }
          },
          I18n.t("created_lowercase")
        ),
        h("div.topic-map-post.created-at", [
          avatarFor("tiny", {
            username: attrs.createdByUsername,
            template: attrs.createdByAvatarTemplate,
            name: attrs.createdByName
          }),
          dateNode(attrs.topicCreatedAt)
        ])
      ])
    );
    contents.push(
      h(
        "li",
        h("a", { attributes: { href: attrs.lastPostUrl } }, [
          h(
            "h4",
            {
              attributes: { role: "presentation" }
            },
            I18n.t("last_reply_lowercase")
          ),
          h("div.topic-map-post.last-reply", [
            avatarFor("tiny", {
              username: attrs.lastPostUsername,
              template: attrs.lastPostAvatarTemplate,
              name: attrs.lastPostName
            }),
            dateNode(attrs.lastPostAt)
          ])
        ])
      )
    );
    contents.push(
      h("li", [
        numberNode(attrs.topicReplyCount),
        h(
          "h4",
          {
            attributes: { role: "presentation" }
          },
          I18n.t("replies_lowercase", {
            count: attrs.topicReplyCount
          }).toString()
        )
      ])
    );
    contents.push(
      h("li.secondary", [
        numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
        h(
          "h4",
          {
            attributes: { role: "presentation" }
          },
          I18n.t("views_lowercase", { count: attrs.topicViews }).toString()
        )
      ])
    );

    if (attrs.participantCount > 0) {
      contents.push(
        h("li.secondary", [
          numberNode(attrs.participantCount),
          h(
            "h4",
            {
              attributes: { role: "presentation" }
            },
            I18n.t("users_lowercase", {
              count: attrs.participantCount
            }).toString()
          )
        ])
      );
    }

    if (attrs.topicLikeCount) {
      contents.push(
        h("li.secondary", [
          numberNode(attrs.topicLikeCount),
          h(
            "h4",
            {
              attributes: { role: "presentation" }
            },
            I18n.t("likes_lowercase", {
              count: attrs.topicLikeCount
            }).toString()
          )
        ])
      );
    }

    if (attrs.topicLinkLength > 0) {
      contents.push(
        h("li.secondary", [
          numberNode(attrs.topicLinkLength),
          h(
            "h4",
            {
              attributes: { role: "presentation" }
            },
            I18n.t("links_lowercase", {
              count: attrs.topicLinkLength
            }).toString()
          )
        ])
      );
    }

    if (
      state.collapsed &&
      attrs.topicPostsCount > 2 &&
      attrs.participants &&
      attrs.participants.length > 0
    ) {
      const participants = renderParticipants.call(
        this,
        attrs.userFilters,
        attrs.participants.slice(0, 3)
      );
      contents.push(h("li.avatars", participants));
    }

    const nav = h(
      "nav.buttons",
      this.attach("button", {
        title: "topic.toggle_information",
        icon: state.collapsed ? "chevron-down" : "chevron-up",
        action: "toggleMap",
        className: "btn"
      })
    );

    return [nav, h("ul.clearfix", contents)];
  }
});

createWidget("topic-map-link", {
  tagName: "a.topic-link.track-link",

  buildClasses(attrs) {
    if (attrs.attachment) {
      return "attachment";
    }
  },

  buildAttributes(attrs) {
    return {
      href: attrs.url,
      target: "_blank",
      "data-user-id": attrs.user_id,
      "data-ignore-post-id": "true",
      title: attrs.url,
      rel: "nofollow ugc noopener"
    };
  },

  html(attrs) {
    let content = attrs.title || attrs.url;
    const truncateLength = 85;

    if (content.length > truncateLength) {
      content = `${content.substr(0, truncateLength).trim()}...`;
    }

    return attrs.title ? replaceEmoji(content) : content;
  }
});

createWidget("topic-map-expanded", {
  tagName: "section.topic-map-expanded",
  buildKey: attrs => `topic-map-expanded-${attrs.id}`,

  defaultState() {
    return { allLinksShown: false };
  },

  html(attrs, state) {
    let avatars;

    if (attrs.participants && attrs.participants.length > 0) {
      avatars = h("section.avatars.clearfix", [
        h("h3", I18n.t("topic_map.participants_title")),
        renderParticipants.call(this, attrs.userFilters, attrs.participants)
      ]);
    }

    const result = [avatars];
    if (attrs.topicLinks) {
      const toShow = state.allLinksShown
        ? attrs.topicLinks
        : attrs.topicLinks.slice(0, LINKS_SHOWN);

      const links = toShow.map(l => {
        let host = "";

        if (l.title && l.title.length) {
          const rootDomain = l.root_domain;

          if (rootDomain && rootDomain.length) {
            host = h("span.domain", rootDomain);
          }
        }

        return h("tr", [
          h(
            "td",
            h(
              "span.badge.badge-notification.clicks",
              {
                attributes: {
                  title: I18n.t("topic_map.clicks", { count: l.clicks })
                }
              },
              l.clicks.toString()
            )
          ),
          h("td", [this.attach("topic-map-link", l), " ", host])
        ]);
      });

      const showAllLinksContent = [
        h("h3", I18n.t("topic_map.links_title")),
        h("table.topic-links", links)
      ];

      if (!state.allLinksShown && links.length < attrs.topicLinks.length) {
        showAllLinksContent.push(this.attach("topic-map-show-links"));
      }

      const section = h("section.links", showAllLinksContent);
      result.push(section);
    }
    return result;
  },

  showAllLinks() {
    this.state.allLinksShown = true;
  }
});

export default createWidget("topic-map", {
  tagName: "div.topic-map",
  buildKey: attrs => `topic-map-${attrs.id}`,

  defaultState(attrs) {
    return { collapsed: !attrs.hasTopicSummary };
  },

  html(attrs, state) {
    const contents = [this.attach("topic-map-summary", attrs, { state })];

    if (!state.collapsed) {
      contents.push(this.attach("topic-map-expanded", attrs));
    }

    if (attrs.hasTopicSummary) {
      contents.push(this.attach("toggle-topic-summary", attrs));
    }

    if (attrs.showPMMap) {
      contents.push(this.attach("private-message-map", attrs));
    }
    return contents;
  },

  toggleMap() {
    this.state.collapsed = !this.state.collapsed;
  }
});
