import RouteTemplate from "ember-route-template";
import GamificationLeaderboard from "../components/gamification-leaderboard";

export default RouteTemplate(
  <template><GamificationLeaderboard @model={{@controller.model}} /></template>
);
