export default class MentionsParser {
  constructor(engine) {
    this.engine = engine;
  }

  parse(markdown) {
    const tokens = this.engine.parse(markdown);
    const mentions = this.#parse(tokens);
    return [...new Set(mentions)];
  }

  #parse(tokens) {
    const mentions = [];
    let insideMention = false;
    for (const token of tokens) {
      if (token.children) {
        this.#parse(token.children).forEach((mention) =>
          mentions.push(mention)
        );
      } else {
        if (token.type === "mention_open") {
          insideMention = true;
        } else if (insideMention && token.type === "text") {
          mentions.push(this.#extractMention(token.content));
          insideMention = false;
        }
      }
    }

    return mentions;
  }

  #extractMention(mention) {
    return mention.trim().substring(1);
  }
}
