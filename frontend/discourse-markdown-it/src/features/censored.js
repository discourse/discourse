import { censorFn } from "pretty-text/censored-words";

function recurse(tokens, apply) {
  for (const token of tokens) {
    // html_raw is final HTML restored after the sanitizer, so rewriting it here
    // would bypass sanitization
    if (token.type === "html_raw") {
      continue;
    }

    apply(token);
    if (token.children) {
      recurse(token.children, apply);
    }
  }
}

function censorTree(state, censor) {
  if (!state.tokens) {
    return;
  }

  recurse(state.tokens, (token) => {
    if (token.content) {
      token.content = censor(token.content);
    }
  });
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    const censoredRegexps = md.options.discourse.censoredRegexp;

    if (Array.isArray(censoredRegexps) && censoredRegexps.length > 0) {
      const replacement = String.fromCharCode(9632);
      const censor = censorFn(censoredRegexps, replacement);
      md.core.ruler.push("censored", (state) => censorTree(state, censor));
    }
  });
}
