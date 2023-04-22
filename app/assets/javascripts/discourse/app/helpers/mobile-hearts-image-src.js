import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("mobileHearthsBarWidth", function (remainingVotes) {
  return `progress-heart-bar w-${remainingVotes}`;
});
