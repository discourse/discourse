import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

function supportsLookbehind() {
  try {
    return new RegExp("(?<=a)b").test("ab");
  } catch {
    return false;
  }
}

// We're expecting to catch Safari < 16 here, but using feature detection
// instead of user-agent parsing, so that we also warn any other browsers missing
// these features.
const checks = {
  relativeColor: CSS.supports("(color: hsl(from white h s l))"),
  subgrid: CSS.supports("(grid-template-rows: subgrid)"),
  lookbehindRegex: supportsLookbehind(),
};

export default apiInitializer((api) => {
  if (!Object.values(checks).every(Boolean)) {
    // eslint-disable-next-line no-console
    console.error("Feature detection result", checks);
    api.addGlobalNotice(
      i18n("safari_15_warning", { url: "https://meta.discourse.org/t/358131" }),
      "browser-deprecation-warning",
      {
        dismissable: true,
        level: "warn",
        dismissDuration: moment.duration(1, "week"),
      }
    );
  }
});
