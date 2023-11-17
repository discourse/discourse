import shuffle from "lodash/shuffle";
import words from "lodash/words";

function recurse(tokens, apply) {
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].type === "html_raw" && tokens[i].onebox) {
      continue;
    }

    apply(tokens[i]);

    if (tokens[i].children) {
      recurse(tokens[i].children, apply);
    }
  }
}

function scrambleTree(state) {
  if (!state.tokens) {
    return;
  }

  recurse(state.tokens, (token) => {
    if (token.content) {
      token.content = scramble(token.content);
    }
  });
}

function scramble(text) {
  return shuffle(words(text)).join(" ");
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.core.ruler.push("scramble", (state) => scrambleTree(state));
  });
}
