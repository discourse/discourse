import { SWIPE_DIRECTIONS, SWIPE_THRESHOLD } from "../constants";

export function getSwipeDirection({
  touchstartX,
  touchstartY,
  touchendX,
  touchendY,
}) {
  const diffX = touchstartX - touchendX;
  const absDiffX = Math.abs(diffX);

  const diffY = touchstartY - touchendY;
  const absDiffY = Math.abs(diffY);

  if (absDiffX > SWIPE_THRESHOLD) {
    return Math.sign(diffX) > 0
      ? SWIPE_DIRECTIONS.RIGHT
      : SWIPE_DIRECTIONS.LEFT;
  }

  if (absDiffY > SWIPE_THRESHOLD) {
    return Math.sign(diffY) > 0 ? SWIPE_DIRECTIONS.UP : SWIPE_DIRECTIONS.DOWN;
  }

  return false;
}
