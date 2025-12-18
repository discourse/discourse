import { modifier } from "ember-modifier";
import {
  applyHtmlDecorators,
  NON_STREAM_HTML_DECORATOR,
  NULL_HELPER,
} from "discourse/components/decorated-html";

/** Modifier that applies cooked content decorators to an element's existing content. */
export default modifier((element) => {
  const cleanups = applyHtmlDecorators(
    element,
    NULL_HELPER,
    NON_STREAM_HTML_DECORATOR
  );

  return () => cleanups.forEach((fn) => fn());
});
