import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "topic-status",
  "span.topic-statuses",
  hbs`<TopicStatus
    @topic={{@data.topic}}
    @disableActions={{@data.disableActions}}
    @tagName=""
  />`
);
