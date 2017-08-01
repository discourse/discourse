import { censorFn } from 'pretty-text/censored-words';

function recurse(tokens, apply) {
  let i;
  for(i=0;i<tokens.length;i++) {
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

  recurse(state.tokens, token => {
    if (token.content) {
      token.content = censor(token.content);
    }
  });
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.censoredPattern = siteSettings.censored_pattern;
  });

  helper.registerPlugin(md => {
    const words = md.options.discourse.censoredWords;
    const patterns = md.options.discourse.censoredPattern;

    if ((words && words.length > 0) || (patterns && patterns.length > 0)) {
      const replacement = String.fromCharCode(9632);
      const censor = censorFn(words, patterns, replacement);
      md.core.ruler.push('censored', state => censorTree(state, censor));
    }
  });
}
