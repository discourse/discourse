import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

export default createWidget("discourse-poll", {
  tagName: "div",
  buildKey: (attrs) => `poll-${attrs.id}`,
  services: ["dialog"],

  buildAttributes(attrs) {
    let cssClasses = "poll-outer";
    if (attrs.poll.chart_type === PIE_CHART_TYPE) {
      cssClasses += " pie";
    }
    return {
      class: cssClasses,
      "data-poll-name": attrs.poll.name,
      "data-poll-type": attrs.poll.type,
    };
  },

  html(attrs) {
    return [
      new RenderGlimmer(
        this,
        "div.poll",
        hbs`<Poll @attrs={{@data.attrs}} @preloadedVoters={{@data.preloadedVoters}} @options={{@data.options}} />`,
        {
          attrs,
          preloadedVoters: attrs.poll.preloaded_voters,
          options: attrs.poll.options,
        }
      ),
    ];
  },
});
