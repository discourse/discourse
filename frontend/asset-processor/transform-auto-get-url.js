// A Glimmer AST transform that automatically wraps URL-bearing attribute values
// on native elements in `getURL`, so the subfolder base path is preserved for
// every rendered link/image — including for middle-click and "open in new tab",
// which follow the raw href and bypass `DiscourseURL.routeTo`.
//
// Before:  <a href={{event.post.url}}>      <a href="/about">      <img src="/t/{{id}}">
// After:   <a href={{getURL event.post.url}}>  <a href={{getURL "/about"}}>  <img src={{getURL (concat "/t/" id)}}>
//
// `getURL` is idempotent and a no-op on external/already-prefixed URLs, so
// applying it here can never double-prefix or rewrite an external link. The
// import is injected via `jsutils.bindImport`, which adds a lexical scope
// binding that resolves in both strict-mode (.gjs) and loose-mode (.hbs)
// templates.

// Native elements and the attributes on them that carry a navigable/loadable
// URL. We deliberately key by tag so we only ever touch real DOM URL slots and
// never a component (which receives URLs via `@args` and prefixes them itself).
const URL_ATTRS_BY_TAG = {
  a: ["href"],
  area: ["href"],
  link: ["href"],
  img: ["src"],
  source: ["src"], // `srcset` is intentionally excluded (multi-URL syntax)
  track: ["src"],
  iframe: ["src"],
  embed: ["src"],
  audio: ["src"],
  video: ["src", "poster"],
  script: ["src"],
  input: ["src", "formaction"],
  button: ["formaction"],
  form: ["action"],
  use: ["href"], // SVG
  image: ["href"], // SVG <image>
};

// Helper heads whose output is already base-path-aware. Skipping these keeps the
// emitted markup clean (no redundant double wrap) even though getURL would be a
// safe no-op anyway.
const SAFE_MUSTACHE_HEADS = new Set([
  "getURL",
  "getURLWithCDN",
  "get-url",
  "userPath",
  "groupPath",
]);

// A root-relative internal path is the only literal we prefix. Anything else —
// external (`https://`), protocol-relative (`//cdn`), anchors (`#x`), schemes
// (`mailto:`), or genuinely relative (`images/x`) — is left untouched.
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

  // Without jsutils we cannot inject the import, so we no-op rather than emit a
  // broken reference. This keeps any build path that lacks the helper safe.
  if (!jsutils) {
    return { name: "auto-get-url", visitor: {} };
  }

  let boundGetURL;
  function getURLPath(target) {
    if (!boundGetURL) {
      boundGetURL = jsutils.bindImport(
        "discourse/lib/get-url",
        "default",
        target,
        { nameHint: "getURL" }
      );
    }
    return b.path(boundGetURL);
  }

  // `concat` is not an auto-scoped keyword in strict-mode (.gjs) templates, so
  // when we synthesize a `(concat ...)` for a literal+binding href we must
  // import it. bindImport also adds the binding harmlessly in loose mode.
  let boundConcat;
  function concatPath(target) {
    if (!boundConcat) {
      boundConcat = jsutils.bindImport("@ember/helper", "concat", target, {
        nameHint: "concat",
      });
    }
    return b.path(boundConcat);
  }

  // Convert a MustacheStatement (an attribute binding or a concat part) into an
  // expression usable as a helper param: a bare path stays a path, anything with
  // params/hash becomes a sub-expression.
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

          // href="/t/123"
          if (value.type === "TextNode") {
            if (isInternalLiteral(value.chars)) {
              attr.value = wrap(b.string(value.chars), path);
            }
            continue;
          }

          // href={{event.post.url}} / href={{concat ...}} / href={{if ...}}
          if (value.type === "MustacheStatement") {
            const head = value.path.head?.name ?? value.path.original;
            if (SAFE_MUSTACHE_HEADS.has(head)) {
              continue;
            }
            attr.value = wrap(mustacheToExpression(value), path);
            continue;
          }

          // href="/t/{{this.id}}" — a literal/binding mix parses to a concat.
          // Only prefix when the leading literal is an internal path.
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

// Participate in template-compiler caching so edits to this file bust stale
// compiled templates (mirrors transform-action-syntax.js).
module.exports.baseDir = () => __dirname;
module.exports.cacheKey = () => "auto-get-url";
