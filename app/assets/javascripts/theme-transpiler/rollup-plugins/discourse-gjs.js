import { Preprocessor } from "../content-tag";

const preprocessor = new Preprocessor();

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
        let { code, map } = preprocessor.process(input, {
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
