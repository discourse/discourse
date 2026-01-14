import { censorFn } from "pretty-text/censored-words";

function recurse(tokens, apply) {
  let i;
  for (i = 0; i < tokens.length; i++) {
    if (tokens[i].type === "html_raw" && tokens[i].onebox) {
      continue;
    }

    apply(tokens[i]);
    if (tokens[i].children) {
      recurse(tokens[i].children, apply);
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
