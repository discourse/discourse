import markdownit from "markdown-it";
import AllowLister from "pretty-text/allow-lister";
import guid from "pretty-text/guid";
import { sanitize } from "pretty-text/sanitizer";
import { TextPostProcessRuler } from "./features/text-post-process";

// note, this will mutate options due to the way the API is designed
// may need a refactor
export default function makeEngine(
  options,
  markdownItOptions,
  markdownItRules
) {
  const engine = makeMarkdownIt(markdownItOptions, markdownItRules);

  const quotes =
    options.discourse.limitedSiteSettings.markdownTypographerQuotationMarks;

  if (quotes) {
    engine.options.quotes = quotes.split("|");
  }

  const tlds = options.discourse.limitedSiteSettings.markdownLinkifyTlds || "";
  engine.linkify.tlds(tlds.split("|"));

  setupUrlDecoding(engine);
  setupHoister(engine);
  setupImageAndPlayableMediaRenderer(engine);
  setupAttachments(engine);
  setupBlockBBCode(engine);
  setupInlineBBCode(engine);
  setupTextPostProcessRuler(engine);

  options.engine = engine;

  for (const [feature, callback] of options.pluginCallbacks) {
    if (options.discourse.features[feature]) {
      if (callback === null || callback === undefined) {
        // eslint-disable-next-line no-console
        console.log("BAD MARKDOWN CALLBACK FOUND");
        // eslint-disable-next-line no-console
        console.log(`FEATURE IS: ${feature}`);
      }
      engine.use(callback);
    }
  }

  // top level markdown it notifier
  options.markdownIt = true;
  options.setup = true;

  if (!options.discourse.sanitizer || !options.sanitizer) {
    const allowLister = new AllowLister(options.discourse);

    options.allowListed.forEach(([feature, info]) => {
      allowLister.allowListFeature(feature, info);
    });

    options.sanitizer = options.discourse.sanitizer = options.discourse.sanitize
      ? (a) => sanitize(a, allowLister)
      : (a) => a;
  }
}

export function cook(raw, options) {
  // we still have to hoist html_raw nodes so they bypass the allowlister
  // this is the case for oneboxes and also certain plugins that require
  // raw HTML rendering within markdown bbcode rules
  options.discourse.hoisted ??= {};

  const rendered = options.engine.render(raw);
  let cooked = options.discourse.sanitizer(rendered).trim();

  // opts.discourse.hoisted guid keys will be deleted within here to
  // keep the object empty
  cooked = unhoistForCooked(options.discourse.hoisted, cooked);

  return cooked;
}

function makeMarkdownIt(markdownItOptions, markdownItRules) {
  if (markdownItRules) {
    // Preset for "zero", https://github.com/markdown-it/markdown-it/blob/master/lib/presets/zero.js
    return markdownit("zero", markdownItOptions).enable(markdownItRules);
  } else {
    return markdownit(markdownItOptions);
  }
}

function setupUrlDecoding(engine) {
  // this fixed a subtle issue where %20 is decoded as space in
  // automatic urls
  engine.utils.lib.mdurl.decode.defaultChars = ";/?:@&=+$,# ";
}

// hoists html_raw tokens out of the render flow and replaces them
// with a GUID. this GUID is then replaced with the final raw HTML
// content in unhoistForCooked
function renderHoisted(tokens, idx, options) {
  const content = tokens[idx].content;
  if (content && content.length > 0) {
    let id = guid();
    options.discourse.hoisted[id] = content;
    return id;
  } else {
    return "";
  }
}

function unhoistForCooked(hoisted, cooked) {
  const keys = Object.keys(hoisted);
  if (keys.length) {
    let found = true;

    const unhoist = function (key) {
      cooked = cooked.replace(new RegExp(key, "g"), function () {
        found = true;
        return hoisted[key];
      });
      delete hoisted[key];
    };

    while (found) {
      found = false;
      keys.forEach(unhoist);
    }
  }

  return cooked;
}

// html_raw tokens, funnily enough, render raw HTML via renderHoisted and
// unhoistForCooked
function setupHoister(engine) {
  engine.renderer.rules.html_raw = renderHoisted;
}

// exported for test only
export function extractDataAttribute(str) {
  let sep = str.indexOf("=");
  if (sep === -1) {
    return null;
  }

  const key = `data-${str.slice(0, sep)}`.toLowerCase();
  if (!/^[A-Za-z]+[\w\-\:\.]*$/.test(key)) {
    return null;
  }

  const value = str.slice(sep + 1);
  return [key, value];
}

// videoHTML and audioHTML follow the same HTML syntax
// as oneboxer.rb when dealing with these formats
function videoHTML(token) {
  const src = token.attrGet("src");
  const origSrc = token.attrGet("data-orig-src");
  const dataOrigSrcAttr = origSrc !== null ? `data-orig-src="${origSrc}"` : "";
  return `<div class="video-placeholder-container" data-video-src="${src}" ${dataOrigSrcAttr}>
  </div>`;
}

function audioHTML(token) {
  const src = token.attrGet("src");
  const origSrc = token.attrGet("data-orig-src");
  const dataOrigSrcAttr = origSrc !== null ? `data-orig-src="${origSrc}"` : "";
  return `<audio preload="metadata" controls>
    <source src="${src}" ${dataOrigSrcAttr}>
    <a href="${src}">${src}</a>
  </audio>`;
}

const IMG_SIZE_REGEX =
  /^([1-9]+[0-9]*)x([1-9]+[0-9]*)(\s*,\s*(x?)([1-9][0-9]{0,2}?)([%x]?))?$/;
function renderImageOrPlayableMedia(tokens, idx, options, env, slf) {
  const token = tokens[idx];
  const alt = slf.renderInlineAsText(token.children, options, env);
  const split = alt.split("|");
  const altSplit = [split[0]];

  // markdown-it supports returning HTML instead of continuing to render the current token
  // see https://github.com/markdown-it/markdown-it/blob/master/docs/architecture.md#renderer
  // handles |video and |audio alt transformations for image tags
  if (split[1] === "video") {
    if (
      options.discourse.previewing &&
      !options.discourse.limitedSiteSettings.enableDiffhtmlPreview
    ) {
      const origSrc = token.attrGet("data-orig-src") || token.attrGet("src");
      const origSrcId = origSrc
        .substring(origSrc.lastIndexOf("/") + 1)
        .split(".")[0];
      return `<div class="onebox-placeholder-container" data-orig-src-id="${origSrcId}">
        <span class="placeholder-icon video"></span>
      </div>`;
    } else {
      return videoHTML(token);
    }
  } else if (split[1] === "audio") {
    return audioHTML(token);
  }

  // parsing ![myimage|500x300]() or ![myimage|75%]() or ![myimage|500x300, 75%]
  for (let i = 1, match, data; i < split.length; ++i) {
    if ((match = split[i].match(IMG_SIZE_REGEX)) && match[1] && match[2]) {
      let width = match[1];
      let height = match[2];

      // calculate using percentage
      if (match[5] && match[6] && match[6] === "%") {
        let percent = parseFloat(match[5]) / 100.0;
        width = parseInt(width * percent, 10);
        height = parseInt(height * percent, 10);
      }

      // calculate using only given width
      if (match[5] && match[6] && match[6] === "x") {
        let wr = parseFloat(match[5]) / width;
        width = parseInt(match[5], 10);
        height = parseInt(height * wr, 10);
      }

      // calculate using only given height
      if (match[5] && match[4] && match[4] === "x" && !match[6]) {
        let hr = parseFloat(match[5]) / height;
        height = parseInt(match[5], 10);
        width = parseInt(width * hr, 10);
      }

      if (token.attrIndex("width") === -1) {
        token.attrs.push(["width", width]);
      }

      if (token.attrIndex("height") === -1) {
        token.attrs.push(["height", height]);
      }

      if (
        options.discourse.previewing &&
        match[6] !== "x" &&
        match[4] !== "x"
      ) {
        token.attrs.push(["class", "resizable"]);
      }
    } else if ((data = extractDataAttribute(split[i]))) {
      token.attrs.push(data);
    } else if (split[i] === "thumbnail") {
      token.attrs.push(["data-thumbnail", "true"]);
    } else {
      altSplit.push(split[i]);
    }
  }

  const altValue = altSplit.join("|").trim();
  if (altValue === "") {
    token.attrSet("role", "presentation");
  } else {
    token.attrSet("alt", altValue);
  }

  return slf.renderToken(tokens, idx, options);
}

// we have taken over the ![]() syntax in markdown to
// be able to render a video or audio URL as well as the
// image using |video and |audio in the text inside []
function setupImageAndPlayableMediaRenderer(engine) {
  engine.renderer.rules.image = renderImageOrPlayableMedia;
}

// discourse-encrypt wants this?
export const ATTACHMENT_CSS_CLASS = "attachment";

function renderAttachment(tokens, idx, options, env, slf) {
  const linkToken = tokens[idx];
  const textToken = tokens[idx + 1];

  const split = textToken.content.split("|");
  const contentSplit = [];

  for (let i = 0, data; i < split.length; ++i) {
    if (split[i] === ATTACHMENT_CSS_CLASS) {
      linkToken.attrs.unshift(["class", split[i]]);
    } else if ((data = extractDataAttribute(split[i]))) {
      linkToken.attrs.push(data);
    } else {
      contentSplit.push(split[i]);
    }
  }

  if (contentSplit.length > 0) {
    textToken.content = contentSplit.join("|");
  }

  return slf.renderToken(tokens, idx, options);
}

function setupAttachments(engine) {
  engine.renderer.rules.link_open = renderAttachment;
}

// TODO we may just use a proper ruler from markdown it... this is a basic proxy
class Ruler {
  constructor() {
    this.rules = [];
  }

  getRules() {
    return this.rules;
  }

  getRuleForTag(tag) {
    this.ensureCache();
    if (this.cache.hasOwnProperty(tag)) {
      return this.cache[tag];
    }
  }

  ensureCache() {
    if (this.cache) {
      return;
    }

    this.cache = {};
    for (let i = this.rules.length - 1; i >= 0; i--) {
      let info = this.rules[i];
      this.cache[info.rule.tag] = info;
    }
  }

  push(name, rule) {
    this.rules.push({ name, rule });
    this.cache = null;
  }
}

// block bb code ruler for parsing of quotes / code / polls
function setupBlockBBCode(engine) {
  engine.block.bbcode = { ruler: new Ruler() };
}

// inline bbcode ruler for parsing of spoiler tags, discourse-chart etc
function setupInlineBBCode(engine) {
  engine.inline.bbcode = { ruler: new Ruler() };
}

// rule for text replacement via regex, used for @mentions, category hashtags, etc.
function setupTextPostProcessRuler(engine) {
  engine.core.textPostProcess = { ruler: new TextPostProcessRuler() };
}
