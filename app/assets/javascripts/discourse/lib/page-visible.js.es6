// for android we test webkit
var hiddenProperty =
  document.hidden !== undefined
    ? "hidden"
    : document.webkitHidden !== undefined
    ? "webkitHidden"
    : undefined;

export default function() {
  if (hiddenProperty !== undefined) {
    return !document[hiddenProperty];
  } else {
    return document && document.hasFocus;
  }
}
