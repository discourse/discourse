// Support for the newline behavior in markdown that most expect. Look through all text nodes
// in the tree, replace any new lines with `br`s.

export function setup(helper) {
  helper.postProcessText((text, event) => {
    const { options, insideCounts } = event;
    if (options.traditionalMarkdownLinebreaks || (insideCounts.pre > 0)) { return; }

    if (text === "\n") {
      // If the tag is just a new line, replace it with a `<br>`
      return [['br']];
    } else {
      // If the text node contains new lines, perhaps with text between them, insert the
      // `<br>` tags.
      const split = text.split(/\n+/);
      if (split.length) {
        const replacement = [];
        for (var i=0; i<split.length; i++) {
          if (split[i].length > 0) { replacement.push(split[i]); }
          if (i !== split.length-1) { replacement.push(['br']); }
        }

        return replacement;
      }
    }
  });
}
