let ajax;
if (window.Discourse) {
  ajax = requirejs("discourse/lib/ajax").ajax;
} else {
  ajax = requirejs("wizard/lib/ajax").ajax;
}

export { ajax };
