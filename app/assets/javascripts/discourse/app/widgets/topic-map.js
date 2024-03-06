import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("topic-map", {
  tagName: "div.topic-map",
  buildKey: (attrs) => `topic-map-${attrs.id}`,

  defaultState(attrs) {
    return { collapsed: !attrs.hasTopRepliesSummary };
  },

  html(attrs, state) {
    const contents = [this.buildTopicMapSummary(attrs, state)];

    if (!state.collapsed) {
      contents.push(this.buildTopicMapExpanded(attrs));
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

  buildTopicMapExpanded(attrs) {
    return new RenderGlimmer(
      this,
      "section.topic-map-expanded",
      hbs`<TopicMap::TopicMapExpanded
        @postAttrs={{@data.postAttrs}}
      />`,
      {
        postAttrs: attrs,
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
