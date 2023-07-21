import { avatarFor, avatarImg } from "discourse/widgets/post";
import { dateNode, numberNode } from "discourse/helpers/node";
import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { replaceEmoji } from "discourse/widgets/emoji";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import { userPath } from "discourse/lib/url";

const LINKS_SHOWN = 5;

function renderParticipants(userFilters, participants) {
  if (!participants) {
    return;
  }

  userFilters = userFilters || [];
  return participants.map((p) => {
    return this.attach("topic-participant", p, {
      state: { toggled: userFilters.includes(p.username) },
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
        className: "btn",
      })
    );
  },

  showLinks() {
    this.sendWidgetAction("showAllLinks");
  },
});

let addTopicParticipantClassesCallbacks = null;
export function addTopicParticipantClassesCallback(callback) {
  addTopicParticipantClassesCallbacks =
    addTopicParticipantClassesCallbacks || [];
  addTopicParticipantClassesCallbacks.push(callback);
}
createWidget("topic-participant", {
  buildClasses(attrs) {
    const classNames = [];
    if (attrs.primary_group_name) {
      classNames.push(`group-${attrs.primary_group_name}`);
    }
    if (addTopicParticipantClassesCallbacks) {
      for (let i = 0; i < addTopicParticipantClassesCallbacks.length; i++) {
        let pluginClasses = addTopicParticipantClassesCallbacks[i].call(
          this,
          attrs
        );
        if (pluginClasses) {
          classNames.push.apply(classNames, pluginClasses);
        }
      }
    }
    return classNames;
  },

  html(attrs, state) {
    const linkContents = [
      avatarImg("medium", {
        username: attrs.username,
        template: attrs.avatar_template,
        name: attrs.name,
      }),
    ];

    if (attrs.post_count > 1) {
      linkContents.push(h("span.post-count", attrs.post_count.toString()));
    }

    if (attrs.flair_group_id) {
      if (attrs.flair_url || attrs.flair_bg_color) {
        linkContents.push(this.attach("avatar-flair", attrs));
      } else {
        const autoFlairAttrs = autoGroupFlairForUser(this.site, attrs);
        if (autoFlairAttrs) {
          linkContents.push(this.attach("avatar-flair", autoFlairAttrs));
        }
      }
    }
    return h(
      "a.poster.trigger-user-card",
      {
        className: state.toggled ? "toggled" : null,
        attributes: {
          title: attrs.username,
          "data-user-card": attrs.username,
          href: userPath(attrs.username),
        },
      },
      linkContents
    );
  },
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
      h("li.created-at", [
        h(
          "h4",
          {
            attributes: { role: "presentation" },
          },
          I18n.t("created_lowercase")
        ),
        h("div.topic-map-post.created-at", [
          avatarFor("tiny", {
            username: attrs.createdByUsername,
            template: attrs.createdByAvatarTemplate,
            name: attrs.createdByName,
          }),
          dateNode(attrs.topicCreatedAt),
        ]),
      ])
    );
    contents.push(
      h(
        "li.last-reply",
        h("a", { attributes: { href: attrs.lastPostUrl } }, [
          h(
            "h4",
            {
              attributes: { role: "presentation" },
            },
            I18n.t("last_reply_lowercase")
          ),
          h("div.topic-map-post.last-reply", [
            avatarFor("tiny", {
              username: attrs.lastPostUsername,
              template: attrs.lastPostAvatarTemplate,
              name: attrs.lastPostName,
            }),
            dateNode(attrs.lastPostAt),
          ]),
        ])
      )
    );
    contents.push(
      h("li.replies", [
        numberNode(attrs.topicReplyCount),
        h(
          "h4",
          {
            attributes: { role: "presentation" },
          },
          I18n.t("replies_lowercase", {
            count: attrs.topicReplyCount,
          }).toString()
        ),
      ])
    );
    contents.push(
      h("li.secondary.views", [
        numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
        h(
          "h4",
          {
            attributes: { role: "presentation" },
          },
          I18n.t("views_lowercase", { count: attrs.topicViews }).toString()
        ),
      ])
    );

    if (attrs.participantCount > 0) {
      contents.push(
        h("li.secondary.users", [
          numberNode(attrs.participantCount),
          h(
            "h4",
            {
              attributes: { role: "presentation" },
            },
            I18n.t("users_lowercase", {
              count: attrs.participantCount,
            }).toString()
          ),
        ])
      );
    }

    if (attrs.topicLikeCount) {
      contents.push(
        h("li.secondary.likes", [
          numberNode(attrs.topicLikeCount),
          h(
            "h4",
            {
              attributes: { role: "presentation" },
            },
            I18n.t("likes_lowercase", {
              count: attrs.topicLikeCount,
            }).toString()
          ),
        ])
      );
    }

    if (attrs.topicLinkLength > 0) {
      contents.push(
        h("li.secondary.links", [
          numberNode(attrs.topicLinkLength),
          h(
            "h4",
            {
              attributes: { role: "presentation" },
            },
            I18n.t("links_lowercase", {
              count: attrs.topicLinkLength,
            }).toString()
          ),
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
        title: state.collapsed
          ? "topic.expand_details"
          : "topic.collapse_details",
        icon: state.collapsed ? "chevron-down" : "chevron-up",
        ariaExpanded: state.collapsed ? "false" : "true",
        ariaControls: "topic-map-expanded",
        action: "toggleMap",
        className: "btn",
      })
    );

    return [nav, h("ul", contents)];
  },
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
      rel: "nofollow ugc noopener",
    };
  },

  html(attrs) {
    let content = attrs.title || attrs.url;
    const truncateLength = 85;

    if (content.length > truncateLength) {
      content = `${content.slice(0, truncateLength).trim()}...`;
    }

    return attrs.title ? replaceEmoji(content) : content;
  },
});

createWidget("topic-map-expanded", {
  tagName: "section.topic-map-expanded#topic-map-expanded",
  buildKey: (attrs) => `topic-map-expanded-${attrs.id}`,

  defaultState() {
    return { allLinksShown: false };
  },

  html(attrs, state) {
    let avatars;

    if (attrs.participants && attrs.participants.length > 0) {
      avatars = h("section.avatars", [
        h("h3", I18n.t("topic_map.participants_title")),
        renderParticipants.call(this, attrs.userFilters, attrs.participants),
      ]);
    }

    const result = [avatars];
    if (attrs.topicLinks) {
      const toShow = state.allLinksShown
        ? attrs.topicLinks
        : attrs.topicLinks.slice(0, LINKS_SHOWN);

      const links = toShow.map((l) => {
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
                  title: I18n.t("topic_map.clicks", { count: l.clicks }),
                },
              },
              l.clicks.toString()
            )
          ),
          h("td", [this.attach("topic-map-link", l), " ", host]),
        ]);
      });

      const showAllLinksContent = [
        h("h3", I18n.t("topic_map.links_title")),
        h("table.topic-links", links),
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
  },
});

export default createWidget("topic-map", {
  tagName: "div.topic-map",
  buildKey: (attrs) => `topic-map-${attrs.id}`,

  defaultState(attrs) {
    return { collapsed: !attrs.hasTopRepliesSummary };
  },

  html(attrs, state) {
    const contents = [this.attach("topic-map-summary", attrs, { state })];

    if (!state.collapsed) {
      contents.push(this.attach("topic-map-expanded", attrs));
    }

    if (attrs.hasTopRepliesSummary || attrs.summarizable) {
      contents.push(this.attach("toggle-topic-summary", attrs));
    }

    if (attrs.showPMMap) {
      contents.push(this.attach("private-message-map", attrs));
    }
    return contents;
  },

  toggleMap() {
    this.state.collapsed = !this.state.collapsed;
  },
});
