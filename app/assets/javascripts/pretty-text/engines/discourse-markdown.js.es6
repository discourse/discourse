import guid from 'pretty-text/guid';
import { default as WhiteLister, whiteListFeature } from 'pretty-text/white-lister';
import { escape } from 'pretty-text/sanitizer';

var parser = window.BetterMarkdown,
    MD = parser.Markdown,
    DialectHelpers = parser.DialectHelpers,
    hoisted;

let currentOpts;

const emitters = [];
const preProcessors = [];
const parseNodes = [];

function findEndPos(text, start, stop, args, offset) {
  let endPos, nextStart;
  do {
    endPos = text.indexOf(stop, offset);
    if (endPos === -1) { return -1; }
    nextStart = text.indexOf(start, offset);
    offset = endPos + stop.length;
  } while (nextStart !== -1 && nextStart < endPos);
  return endPos;
}

class DialectHelper {
  constructor() {
    this._dialect = MD.dialects.Discourse = DialectHelpers.subclassDialect(MD.dialects.Gruber);
    this._setup = false;
  }

  escape(str) {
    return escape(str);
  }

  getOptions() {
    return currentOpts;
  }

  registerInlineFeature(featureName, start, fn) {
    this._dialect.inline[start] = function() {
      if (!currentOpts.features[featureName]) { return; }
      return fn.apply(this, arguments);
    };
  }

  addPreProcessorFeature(featureName, fn) {
    preProcessors.push(raw => {
      if (!currentOpts.features[featureName]) { return raw; }
      return fn(raw, hoister);
    });
  }

  /**
    The simplest kind of replacement possible. Replace a stirng token with JsonML.

    For example to replace all occurrances of :) with a smile image:

    ```javascript
      helper.inlineReplace(':)', text => ['img', {src: '/images/smile.png'}]);
    ```
  **/
  inlineReplaceFeature(featureName, token, emitter) {
    this.registerInline(token, (text, match, prev) => {
      if (!currentOpts.features[featureName]) { return; }
      return [token.length, emitter.call(this, token, match, prev)];
    });
  }

  /**
    After the parser has been executed, change the contents of a HTML tag.

    Let's say you want to replace the contents of all code tags to prepend
    "EVIL TROUT HACKED YOUR CODE!":

    ```javascript
      helper.postProcessTag('code', contents => `EVIL TROUT HACKED YOUR CODE!\n\n${contents}`);
    ```
  **/
  postProcessTagFeature(featureName, tag, emitter) {
    this.onParseNode(event => {
      if (!currentOpts.features[featureName]) { return; }
      const node = event.node;
      if (node[0] === tag) {
        node[node.length-1] = emitter(node[node.length-1]);
      }
    });
  }

  /**
    Matches inline using a regular expression. The emitter function is passed
    the matches from the regular expression.

    For example, this auto links URLs:

    ```javascript
      helper.inlineRegexp({
        matcher: /((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
        spaceBoundary: true,
        start: 'http',

        emitter(matches) {
          const url = matches[1];
          return ['a', {href: url}, url];
        }
      });
    ```
  **/
  inlineRegexpFeature(featureName, args) {
    this.registerInline(args.start, function(text, match, prev) {
      if (!currentOpts.features[featureName]) { return; }
      if (invalidBoundary(args, prev)) { return; }

      args.matcher.lastIndex = 0;
      const m = args.matcher.exec(text);
      if (m) {
        const result = args.emitter.call(this, m);
        if (result) {
          return [m[0].length, result];
        }
      }
    });
  }

  /**
    Handles inline replacements surrounded by tokens.

    For example, to handle markdown style bold. Note we use `concat` on the array because
    the contents are JsonML too since we didn't pass `rawContents` as true. This supports
    recursive markup.

    ```javascript
      helper.inlineBetween({
        between: '**',
        wordBoundary: true.
        emitter(contents) {
          return ['strong'].concat(contents);
        }
      });
    ```
  **/
  inlineBetweenFeature(featureName, args) {
    const start = args.start || args.between;
    const stop = args.stop || args.between;
    const startLength = start.length;

    this.registerInline(start, function(text, match, prev) {
      if (!currentOpts.features[featureName]) { return; }
      if (invalidBoundary(args, prev)) { return; }

      const endPos = findEndPos(text, start, stop, args, startLength);
      if (endPos === -1) { return; }
      var between = text.slice(startLength, endPos);

      // If rawcontents is set, don't process inline
      if (!args.rawContents) {
        between = this.processInline(between);
      }

      var contents = args.emitter.call(this, between);
      if (contents) {
        return [endPos+stop.length, contents];
      }
    });
  }

  /**
    Replaces a block of text between a start and stop. As opposed to inline, these
    might span multiple lines.

    Here's an example that takes the content between `[code]` ... `[/code]` and
    puts them inside a `pre` tag:

    ```javascript
      helper.replaceBlock({
        start: /(\[code\])([\s\S]*)/igm,
        stop: '[/code]',
        rawContents: true,

        emitter(blockContents) {
          return ['p', ['pre'].concat(blockContents)];
        }
      });
    ```
  **/
  replaceBlockFeature(featureName, args) {
    function blockFunc(block, next) {
      if (!currentOpts.features[featureName]) { return; }

      const linebreaks = currentOpts.traditionalMarkdownLinebreaks;
      if (linebreaks && args.skipIfTradtionalLinebreaks) { return; }

      args.start.lastIndex = 0;
      const result = [];
      const match = (args.start).exec(block);
      if (!match) { return; }

      const lastChance = () => !next.some(blk => blk.match(args.stop));

      // shave off start tag and leading text, if any.
      const pos = args.start.lastIndex - match[0].length;
      const leading = block.slice(0, pos);
      const trailing = match[2] ? match[2].replace(/^\n*/, "") : "";

      // The other leading block should be processed first! eg a code block wrapped around a code block.
      if (args.withoutLeading && args.withoutLeading.test(leading)) {
        return;
      }

      // just give up if there's no stop tag in this or any next block
      args.stop.lastIndex = block.length - trailing.length;
      if (!args.stop.exec(block) && lastChance()) { return; }
      if (leading.length > 0) {
        var parsedLeading = this.processBlock(MD.mk_block(leading), []);
        if (parsedLeading && parsedLeading[0]) {
          result.push(parsedLeading[0]);
        }
      }
      if (trailing.length > 0) {
        next.unshift(MD.mk_block(trailing, block.trailing,
          block.lineNumber + countLines(leading) + (match[2] ? match[2].length : 0) - trailing.length));
      }

      // go through the available blocks to find the matching stop tag.
      const contentBlocks = [];
      let nesting = 0;
      let actualEndPos = -1;
      let currentBlock;

      blockloop:
      while (currentBlock = next.shift()) {

        // collect all the start and stop tags in the current block
        args.start.lastIndex = 0;
        const startPos = [];
        let m;
        while (m = (args.start).exec(currentBlock)) {
          startPos.push(args.start.lastIndex - m[0].length);
          args.start.lastIndex = args.start.lastIndex - (m[2] ? m[2].length : 0);
        }
        args.stop.lastIndex = 0;
        const endPos = [];
        while (m = (args.stop).exec(currentBlock)) {
          endPos.push(args.stop.lastIndex - m[0].length);
        }

        // go through the available end tags:
        let ep = 0;
        let sp = 0;
        while (ep < endPos.length) {
          if (sp < startPos.length && startPos[sp] < endPos[ep]) {
            // there's an end tag, but there's also another start tag first. we need to go deeper.
            sp++; nesting++;
          } else if (nesting > 0) {
            // found an end tag, but we must go up a level first.
            ep++; nesting--;
          } else {
            // found an end tag and we're at the top: done! -- or: start tag and end tag are
            // identical, (i.e. startPos[sp] == endPos[ep]), so we don't do nesting at all.
            actualEndPos = endPos[ep];
            break blockloop;
          }
        }

        if (lastChance()) {
          // when lastChance() becomes true the first time, currentBlock contains the last
          // end tag available in the input blocks but it's not on the right nesting level
          // or we would have terminated the loop already. the only thing we can do is to
          // treat the last available end tag as tho it were matched with our start tag
          // and let the emitter figure out how to render the garbage inside.
          actualEndPos = endPos[endPos.length - 1];
          break;
        }

        // any left-over start tags still increase the nesting level
        nesting += startPos.length - sp;
        contentBlocks.push(currentBlock);
      }

      const stopLen = currentBlock.match(args.stop)[0].length;
      const before = currentBlock.slice(0, actualEndPos).replace(/\n*$/, "");
      const after = currentBlock.slice(actualEndPos + stopLen).replace(/^\n*/, "");
      if (before.length > 0) contentBlocks.push(MD.mk_block(before, "", currentBlock.lineNumber));
      if (after.length > 0) next.unshift(MD.mk_block(after, currentBlock.trailing, currentBlock.lineNumber + countLines(before)));

      const emitterResult = args.emitter.call(this, contentBlocks, match);
      if (emitterResult) { result.push(emitterResult); }
      return result;
    };

    if (args.priority) {
      blockFunc.priority = args.priority;
    }

    this.registerBlock(args.start.toString(), blockFunc);
  }

  /**
    After the parser has been executed, post process any text nodes in the HTML document.
    This is useful if you want to apply a transformation to the text.

    If you are generating HTML from the text, it is preferable to use the replacer
    functions and do it in the parsing part of the pipeline. This function is best for
    simple transformations or transformations that have to happen after all earlier
    processing is done.

    For example, to convert all text to upper case:

    ```javascript
      helper.postProcessText(function (text) {
        return text.toUpperCase();
      });
    ```
  **/
  postProcessTextFeature(featureName, fn) {
    emitters.push(function () {
      if (!currentOpts.features[featureName]) { return; }
      return fn.apply(this, arguments);
    });
  }

  onParseNodeFeature(featureName, fn) {
    parseNodes.push(function () {
      if (!currentOpts.features[featureName]) { return; }
      return fn.apply(this, arguments);
    });
  }

  registerBlockFeature(featureName, name, fn) {
    const blockFunc = function() {
      if (!currentOpts.features[featureName]) { return; }
      return fn.apply(this, arguments);
    };

    blockFunc.priority = fn.priority;
    this._dialect.block[name] = blockFunc;
  }

  applyFeature(featureName, module) {
    helper.registerInline = (code, fn) => helper.registerInlineFeature(featureName, code, fn);
    helper.replaceBlock = args => helper.replaceBlockFeature(featureName, args);
    helper.addPreProcessor = fn => helper.addPreProcessorFeature(featureName, fn);
    helper.inlineReplace = (token, emitter) => helper.inlineReplaceFeature(featureName, token, emitter);
    helper.postProcessTag = (token, emitter) => helper.postProcessTagFeature(featureName, token, emitter);
    helper.inlineRegexp = args => helper.inlineRegexpFeature(featureName, args);
    helper.inlineBetween = args => helper.inlineBetweenFeature(featureName, args);
    helper.postProcessText = fn => helper.postProcessTextFeature(featureName, fn);
    helper.onParseNode = fn => helper.onParseNodeFeature(featureName, fn);
    helper.registerBlock = (name, fn) => helper.registerBlockFeature(featureName, name, fn);

    module.setup(this);
  }

  setup() {
    if (this._setup) { return; }
    this._setup = true;

    Object.keys(require._eak_seen).forEach(entry => {
      if (entry.indexOf('discourse-markdown') !== -1) {
        const module = require(entry);
        if (module && module.setup) {
          const featureName = entry.split('/').reverse()[0];
          helper.whiteList = info => whiteListFeature(featureName, info);

          this.applyFeature(featureName, module);
          helper.whiteList = undefined;
        }
      }
    });

    MD.buildBlockOrder(this._dialect.block);
    var index = this._dialect.block.__order__.indexOf("code");
    if (index > -1) {
      this._dialect.block.__order__.splice(index, 1);
      this._dialect.block.__order__.unshift("code");
    }
    MD.buildInlinePatterns(this._dialect.inline);
  }
};

const helper = new DialectHelper();

export function cook(raw, opts) {
  currentOpts = opts;

  hoisted = {};
  raw = hoistCodeBlocksAndSpans(raw);

  preProcessors.forEach(p => raw = p(raw));

  const whiteLister = new WhiteLister(opts.features);

  const tree = parser.toHTMLTree(raw, 'Discourse');
  let result = opts.sanitizer(parser.renderJsonML(parseTree(tree, opts)), whiteLister);

  // If we hoisted out anything, put it back
  const keys = Object.keys(hoisted);
  if (keys.length) {
    let found = true;

    function unhoist(key) {
      result = result.replace(new RegExp(key, "g"), function() {
        found = true;
        return hoisted[key];
      });
    };

    while (found) {
      found = false;
      keys.forEach(unhoist);
    }
  }

  return result.trim();
}

export function setup() {
  helper.setup();
}

function processTextNodes(node, event, emitter) {
  if (node.length < 2) { return; }

  if (node[0] === '__RAW') {
    const hash = guid();
    hoisted[hash] = node[1];
    node[1] = hash;
    return;
  }

  for (var j=1; j<node.length; j++) {
    var textContent = node[j];
    if (typeof textContent === "string") {
      var result = emitter(textContent, event);
      if (result) {
        if (result instanceof Array) {
          node.splice.apply(node, [j, 1].concat(result));
        } else {
          node[j] = result;
        }
      } else {
        node[j] = textContent;
      }

    }
  }
}

// Parse a JSON ML tree, using registered handlers to adjust it if necessary.
function parseTree(tree, options, path, insideCounts) {

  if (tree instanceof Array) {
    const event = {node: tree, options, path, insideCounts: insideCounts || {}};
    parseNodes.forEach(fn => fn(event));

    for (var j=0; j<emitters.length; j++) {
      processTextNodes(tree, event, emitters[j]);
    }

    path = path || [];
    insideCounts = insideCounts || {};

    path.push(tree);

    for (var i=1; i<tree.length; i++) {
      var n = tree[i],
          tagName = n[0];

      insideCounts[tagName] = (insideCounts[tagName] || 0) + 1;

      if (n && n.length === 2 && n[0] === "p" && /^<!--([\s\S]*)-->$/.exec(n[1])) {
        // Remove paragraphs around comment-only nodes.
        tree[i] = n[1];
      } else {
        parseTree(n, options, path, insideCounts);
      }

      insideCounts[tagName] = insideCounts[tagName] - 1;
    }

    // If raw nodes are in paragraphs, pull them up
    if (tree.length === 2 && tree[0] === 'p' && tree[1] instanceof Array && tree[1][0] === "__RAW") {
      var text = tree[1][1];
      tree[0] = "__RAW";
      tree[1] = text;
    }

    path.pop();
  }
  return tree;
}

// Returns true if there's an invalid word boundary for a match.
function invalidBoundary(args, prev) {
  if (!(args.wordBoundary || args.spaceBoundary || args.spaceOrTagBoundary)) { return false; }

  var last = prev[prev.length - 1];
  if (typeof last !== "string") { return false; }

  if (args.wordBoundary && (!last.match(/\W$/))) { return true; }
  if (args.spaceBoundary && (!last.match(/\s$/))) { return true; }
  if (args.spaceOrTagBoundary && (!last.match(/(\s|\>)$/))) { return true; }
}

function countLines(str) {
  let index = -1, count = 0;
  while ((index = str.indexOf("\n", index + 1)) !== -1) { count++; }
  return count;
}

function hoister(t, target, replacement) {
  const regexp = new RegExp(target.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'), "g");
  if (t.match(regexp)) {
    const hash = guid();
    t = t.replace(regexp, hash);
    hoisted[hash] = replacement;
  }
  return t;
}

function outdent(t) {
  return t.replace(/^([ ]{4}|\t)/gm, "");
}

function removeEmptyLines(t) {
  return t.replace(/^\n+/, "").replace(/\s+$/, "");
}

function hideBackslashEscapedCharacters(t) {
  return t.replace(/\\\\/g, "\u1E800").replace(/\\`/g, "\u1E8001");
}

function showBackslashEscapedCharacters(t) {
  return t.replace(/\u1E8001/g, "\\`").replace(/\u1E800/g, "\\\\");
}

function hoistCodeBlocksAndSpans(text) {
  // replace all "\`" with a single character
  text = hideBackslashEscapedCharacters(text);

  // /!\ the order is important /!\

  // fenced code blocks (AKA GitHub code blocks)
  text = text.replace(/(^\n*|\n)```([a-z0-9\-]*)\n([\s\S]*?)\n```/g, function(_, before, language, content) {
    const hash = guid();
    hoisted[hash] = escape(showBackslashEscapedCharacters(removeEmptyLines(content)));
    return before + "```" + language + "\n" + hash + "\n```";
  });

  // markdown code blocks
  text = text.replace(/(^\n*|\n\n)((?:(?:[ ]{4}|\t).*\n*)+)/g, function(match, before, content, index) {
    // make sure we aren't in a list
    var previousLine = text.slice(0, index).trim().match(/.*$/);
    if (previousLine && previousLine[0].length) {
      previousLine = previousLine[0].trim();
      if (/^(?:\*|\+|-|\d+\.)\s+/.test(previousLine)) {
        return match;
      }
    }
    // we can safely hoist the code block
    const hash = guid();
    hoisted[hash] = escape(outdent(showBackslashEscapedCharacters(removeEmptyLines(content))));
    return before + "    " + hash + "\n";
  });

  // <pre>...</pre> code blocks
  text = text.replace(/(\s|^)<pre>([\s\S]*?)<\/pre>/ig, function(_, before, content) {
    const hash = guid();
    hoisted[hash] = escape(showBackslashEscapedCharacters(removeEmptyLines(content)));
    return before + "<pre>" + hash + "</pre>";
  });

  // code spans (double & single `)
  ["``", "`"].forEach(function(delimiter) {
    var regexp = new RegExp("(^|[^`])" + delimiter + "([^`\\n]+?)" + delimiter + "([^`]|$)", "g");
    text = text.replace(regexp, function(_, before, content, after) {
      const hash = guid();
      hoisted[hash] = escape(showBackslashEscapedCharacters(content.trim()));
      return before + delimiter + hash + delimiter + after;
    });
  });

  // replace back all weird character with "\`"
  return showBackslashEscapedCharacters(text);
}
