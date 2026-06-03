// A Glimmer AST transform that automatically wraps URL-bearing attribute values
// on native elements in `getURLForAttribute`, so the subfolder base path is
// preserved for every rendered link — including for middle-click and "open in
// new tab", which follow the raw href and bypass `DiscourseURL.routeTo`.
//
// Before:  <a href={{event.post.url}}>      <a href="/about">      <a href="/t/{{id}}">
// After:   <a href={{getURL event.post.url}}>  <a href={{getURL "/about"}}>  <a href={{getURL (concat "/t/" id)}}>
//
// `getURLForAttribute` delegates non-empty strings to `getURL` and preserves
// every other value, so Glimmer's attribute-omission semantics for null and
// undefined bindings are unchanged. `getURL` is idempotent and a no-op on
// external or already-prefixed URLs, so the rewrite can never double-prefix or
// rewrite an external link. The import is injected via `jsutils.bindImport`,
// which adds a lexical scope binding that resolves in both strict-mode (.gjs)
// and loose-mode (.hbs) templates.
//
// The scope is limited to anchor `href` and image `src` attributes for now.
// Other URL slots (`form[action]`, `video[poster]`, ...) can be added to
// `URL_ATTRS_BY_TAG` once this has proven itself in production. Keying by tag
// means only real DOM URL slots are ever touched, never a component.

const URL_ATTRS_BY_TAG = {
  a: ["href"],
  img: ["src"],
};

const SAFE_MUSTACHE_HEADS = new Set([
  "getURL",
  "getURLForAttribute",
  "getURLWithCDN",
  "get-url",
  "userPath",
  "groupPath",
]);

function isInternalLiteral(raw) {
  const value = raw.trim();
  if (!value) {
    return false;
  }
  if (value.startsWith("//")) {
    return false;
  }
  return value.startsWith("/");
}

module.exports = function autoGetUrl(env) {
  const { builders: b } = env.syntax;
  const jsutils = env.meta && env.meta.jsutils;

  if (!jsutils) {
    return { name: "auto-get-url", visitor: {} };
  }

  let boundGetURL;
  function getURLPath(target) {
    if (!boundGetURL) {
      boundGetURL = jsutils.bindImport(
        "discourse/lib/get-url",
        "getURLForAttribute",
        target,
        { nameHint: "getURLForAttribute" }
      );
    }
    return b.path(boundGetURL);
  }

  // `concat` is not auto-scoped in strict-mode templates, so a synthesized
  // `(concat ...)` needs its own import.
  let boundConcat;
  function concatPath(target) {
    if (!boundConcat) {
      boundConcat = jsutils.bindImport("@ember/helper", "concat", target, {
        nameHint: "concat",
      });
    }
    return b.path(boundConcat);
  }

  function mustacheToExpression(node) {
    if (node.params.length === 0 && node.hash.pairs.length === 0) {
      return node.path;
    }
    return b.sexpr(node.path, node.params, node.hash);
  }

  function wrap(expression, target) {
    return b.mustache(getURLPath(target), [expression]);
  }

  return {
    name: "auto-get-url",

    visitor: {
      ElementNode(node, path) {
        const attrs = URL_ATTRS_BY_TAG[node.tag.toLowerCase()];
        if (!attrs) {
          return;
        }

        for (const attr of node.attributes) {
          if (!attrs.includes(attr.name)) {
            continue;
          }

          const value = attr.value;

          if (value.type === "TextNode") {
            if (isInternalLiteral(value.chars)) {
              attr.value = wrap(b.string(value.chars), path);
            }
            continue;
          }

          if (value.type === "MustacheStatement") {
            const head = value.path.head?.name ?? value.path.original;
            if (SAFE_MUSTACHE_HEADS.has(head)) {
              continue;
            }
            attr.value = wrap(mustacheToExpression(value), path);
            continue;
          }

          if (value.type === "ConcatStatement") {
            const first = value.parts[0];
            if (first?.type === "TextNode" && isInternalLiteral(first.chars)) {
              const concatParams = value.parts.map((part) =>
                part.type === "TextNode"
                  ? b.string(part.chars)
                  : mustacheToExpression(part)
              );
              attr.value = wrap(b.sexpr(concatPath(path), concatParams), path);
            }
          }
        }
      },
    },
  };
};

module.exports.baseDir = () => __dirname;
module.exports.cacheKey = () => "auto-get-url";
