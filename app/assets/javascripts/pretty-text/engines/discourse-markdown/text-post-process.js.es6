export class TextPostProcessRuler {
  constructor() {
    this.rules = [];
  }

  getRules() {
    return this.rules;
  }

  // TODO error handling
  getMatcher() {
    if (this.matcher) {
      return this.matcher;
    }

    this.matcherIndex = [];

    const rules = [];
    const flags = new Set("g");

    this.rules.forEach(r => {
      const matcher = r.rule.matcher;
      rules.push(`(${matcher.source})`);
      matcher.flags.split("").forEach(f => flags.add(f));
    });

    let i;
    let regexString = "";
    let last = 1;

    // this code is a bit tricky, our matcher may have multiple capture groups
    // we want to dynamically determine how many
    for (i = 0; i < rules.length; i++) {
      this.matcherIndex[i] = last;

      if (i === rules.length - 1) {
        break;
      }

      if (i > 0) {
        regexString = regexString + "|";
      }
      regexString = regexString + rules[i];

      let regex = new RegExp(regexString + "|(x)");
      last = "x".match(regex).length - 1;
    }

    this.matcher = new RegExp(rules.join("|"), [...flags].join(""));
    return this.matcher;
  }

  applyRule(buffer, match, state) {
    let i;
    for (i = 0; i < this.rules.length; i++) {
      let index = this.matcherIndex[i];

      if (match[index]) {
        this.rules[i].rule.onMatch(
          buffer,
          match.slice(index, this.matcherIndex[i + 1]),
          state
        );
        break;
      }
    }
  }

  // TODO validate inputs
  push(name, rule) {
    this.rules.push({ name, rule });
    this.matcher = null;
  }
}

function allowedBoundary(content, index, utils) {
  let code = content.charCodeAt(index);
  return (
    utils.isWhiteSpace(code) || utils.isPunctChar(String.fromCharCode(code))
  );
}

function textPostProcess(content, state, ruler) {
  let result = null;
  let match;
  let pos = 0;

  const matcher = ruler.getMatcher();

  while ((match = matcher.exec(content))) {
    // something is wrong
    if (match.index < pos) break;

    // check boundary
    if (match.index > 0) {
      if (!allowedBoundary(content, match.index - 1, state.md.utils)) {
        continue;
      }
    }

    // check forward boundary as well
    if (match.index + match[0].length < content.length) {
      if (
        !allowedBoundary(content, match.index + match[0].length, state.md.utils)
      ) {
        continue;
      }
    }

    result = result || [];

    if (match.index > pos) {
      let token = new state.Token("text", "", 0);
      token.content = content.slice(pos, match.index);
      result.push(token);
    }

    ruler.applyRule(result, match, state);

    pos = match.index + match[0].length;
  }

  if (result && pos < content.length) {
    let token = new state.Token("text", "", 0);
    token.content = content.slice(pos);
    result.push(token);
  }

  return result;
}

export function setup(helper) {
  helper.registerPlugin(md => {
    const ruler = md.core.textPostProcess.ruler;
    const replacer = (content, state) => textPostProcess(content, state, ruler);

    md.core.ruler.push("text-post-process", state =>
      md.options.discourse.helpers.textReplace(state, replacer, true)
    );
  });
}
