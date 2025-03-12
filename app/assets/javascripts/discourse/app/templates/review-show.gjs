import RouteTemplate from "ember-route-template";
import ReviewableItem from "discourse/components/reviewable-item";

export default RouteTemplate(
  <template><ReviewableItem @reviewable={{@controller.reviewable}} /></template>
);
