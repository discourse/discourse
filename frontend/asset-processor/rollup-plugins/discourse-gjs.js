import { getPreprocessor } from "../content-tag";

export default function discourseGjs() {
  return {
    name: "discourse-gjs",

    transform: {
      // Enforce running the gjs transform before any others like babel that expect valid JS
      order: "pre",
      handler(input, id) {
        if (!id.endsWith(".gjs")) {
          return null;
        }
        let { code, map } = getPreprocessor().process(input, {
          filename: id,
        });
        return {
          code,
          map,
        };
      },
    },
  };
}
