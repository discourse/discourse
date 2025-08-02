import "core-js/actual/url";
import postcssLightDark from "@csstools/postcss-light-dark-function";
import autoprefixer from "autoprefixer";
import postcss from "postcss";
import minmax from "postcss-media-minmax";
import { browsers } from "../discourse/config/targets";
import postcssVariablePrefixer from "./postcss-variable-prefixer";

const postCssProcessor = postcss([
  autoprefixer({
    overrideBrowserslist: browsers,
  }),
  minmax(),
  postcssLightDark,
  postcssVariablePrefixer(),
]);
let lastPostcssError, lastPostcssResult;

globalThis.postCss = async function (css, map, sourcemapFile) {
  try {
    const rawResult = await postCssProcessor.process(css, {
      from: "input.css",
      to: "output.css",
      map: {
        prev: map,
        inline: false,
        absolute: false,
        annotation: sourcemapFile,
      },
    });
    lastPostcssResult = [rawResult.css, rawResult.map?.toString()];
  } catch (e) {
    lastPostcssError = e;
  }
};

globalThis.getPostCssResult = function () {
  const error = lastPostcssError;
  const result = lastPostcssResult;

  lastPostcssError = lastPostcssResult = null;

  if (error) {
    throw error;
  }
  return result;
};
