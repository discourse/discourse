import { htmlSafe } from "@ember/template";
import { hbs } from "ember-cli-htmlbars";
import { h } from "virtual-dom";
import { replaceEmoji } from "discourse/widgets/emoji";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

const LINKS_SHOWN = 5;

function renderParticipants(wrapperElement, title, userFilters, participants) {
  return new RenderGlimmer(
    this,
    wrapperElement,
    hbs`<TopicMap::TopicParticipants
        @title={{@data.title}}
        @participants={{@data.participants}}
        @userFilters={{@data.userFilters}}
      />`,
    {
      title,
      userFilters,
      participants,
    }
  );
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
        className: "btn btn-flat",
      })
    );
  },

  showLinks() {
    this.sendWidgetAction("showAllLinks");
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
      avatars = renderParticipants.call(
        this,
        "section.avatars",
        htmlSafe(`<h3>${I18n.t("topic_map.participants_title")}</h3>`),
        attrs.userFilters,
        attrs.participants
      );
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
    const contents = [this.buildTopicMapSummary(attrs, state)];

    if (!state.collapsed) {
      contents.push(this.attach("topic-map-expanded", attrs));
    }

    if (attrs.hasTopRepliesSummary || attrs.summarizable) {
      contents.push(this.buildSummaryBox(attrs));
    }

    if (attrs.showPMMap) {
      contents.push(this.buildPrivateMessageMap(attrs));
    }
    return contents;
  },

  toggleMap() {
    this.state.collapsed = !this.state.collapsed;
    this.scheduleRerender();
  },

  buildTopicMapSummary(attrs, state) {
    const { collapsed } = state;
    const wrapperClass = collapsed
      ? "section.map.map-collapsed"
      : "section.map";

    return new RenderGlimmer(
      this,
      wrapperClass,
      hbs`<TopicMap::TopicMapSummary
        @postAttrs={{@data.postAttrs}}
        @toggleMap={{@data.toggleMap}}
        @collapsed={{@data.collapsed}}
      />`,
      {
        toggleMap: this.toggleMap.bind(this),
        postAttrs: attrs,
        collapsed,
      }
    );
  },

  buildSummaryBox(attrs) {
    return new RenderGlimmer(
      this,
      "section.information.toggle-summary",
      hbs`<SummaryBox
        @postAttrs={{@data.postAttrs}}
        @actionDispatchFunc={{@data.actionDispatchFunc}}
      />`,
      {
        postAttrs: attrs,
        actionDispatchFunc: (actionName) => {
          this.sendWidgetAction(actionName);
        },
      }
    );
  },

  buildPrivateMessageMap(attrs) {
    return new RenderGlimmer(
      this,
      "section.information.private-message-map",
      hbs`<TopicMap::PrivateMessageMap
        @postAttrs={{@data.postAttrs}}
        @showInvite={{@data.showInvite}}
        @removeAllowedGroup={{@data.removeAllowedGroup}}
        @removeAllowedUser={{@data.removeAllowedUser}}
      />`,
      {
        postAttrs: attrs,
        showInvite: () => this.sendWidgetAction("showInvite"),
        removeAllowedGroup: (group) =>
          this.sendWidgetAction("removeAllowedGroup", group),
        removeAllowedUser: (user) =>
          this.sendWidgetAction("removeAllowedUser", user),
      }
    );
  },
});
