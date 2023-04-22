import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("mobileHeartsImageSrc", function (remainingVotes) {
  let votes = 0;
  if (remainingVotes === 100) {
    votes = 100;
  } else if (remainingVotes > 0 && remainingVotes <= 19) {
    votes = 19;
  } else if (remainingVotes > 19 && remainingVotes <= 36) {
    votes = 36;
  } else if (remainingVotes > 36 && remainingVotes <= 51) {
    votes = 51;
  } else if (remainingVotes > 51 && remainingVotes <= 64) {
    votes = 64;
  } else if (remainingVotes > 64 && remainingVotes <= 75) {
    votes = 75;
  } else if (remainingVotes > 75 && remainingVotes <= 84) {
    votes = 84;
  } else if (remainingVotes > 84 && remainingVotes <= 91) {
    votes = 91;
  } else if (remainingVotes > 91 && remainingVotes <= 96) {
    votes = 96;
  } else if (remainingVotes > 96 && remainingVotes <= 99) {
    votes = 99;
  } else {
    votes = 0;
  }
  let src = `/images/heart-health-${votes}.png`;
  return src;
});
