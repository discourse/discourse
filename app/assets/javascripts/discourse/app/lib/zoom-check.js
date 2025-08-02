import { isTesting } from "discourse/lib/environment";

// return true when the browser viewport is zoomed
export default function isZoomed() {
  return (
    !isTesting() &&
    visualViewport?.scale !== 1 &&
    document.documentElement.clientWidth / window.innerWidth !== 1
  );
}
