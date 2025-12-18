import { modifier } from "ember-modifier";
import {
  applyHtmlDecorators,
  NON_STREAM_HTML_DECORATOR,
  NULL_HELPER,
} from "discourse/components/decorated-html";

/** Modifier that sets element innerHTML and applies cooked content decorators. */
export default modifier((element, [html]) => {
  if (!html) {
    return;
  }

  element.innerHTML = html;

  const cleanups = applyHtmlDecorators(
    element,
    NULL_HELPER,
    NON_STREAM_HTML_DECORATOR
  );

  return () => cleanups.forEach((fn) => fn());
});
