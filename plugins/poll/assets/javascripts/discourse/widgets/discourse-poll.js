import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

const RANKED_CHOICE = "ranked_choice";

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
    attrs.poll.options.forEach((option) => {
      option.rank = 0;
      if (attrs.poll.type === RANKED_CHOICE) {
        attrs.vote.forEach((vote) => {
          if (vote.digest === option.id) {
            option.rank = vote.rank;
          }
        });
      }
    });

    let attributes = Object.assign(attrs);

    return [
      new RenderGlimmer(
        this,
        "div.poll",
        hbs`<PollWrapper
          @attrs={{@data.attributes}}
        />`,
        {
          attributes,
        }
      ),
    ];
  },
});
