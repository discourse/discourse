import WhiteLister from "pretty-text/white-lister";
import { sanitize } from "pretty-text/sanitizer";
import guid from "pretty-text/guid";

export const ATTACHMENT_CSS_CLASS = "attachment";

function deprecate(feature, name) {
  return function() {
    if (window.console && window.console.log) {
      window.console.log(
        feature +
          ": " +
          name +
          " is deprecated, please use the new markdown it APIs"
      );
    }
  };
}

function createHelper(
  featureName,
  opts,
  optionCallbacks,
  pluginCallbacks,
  getOptions,
  whiteListed
) {
  let helper = {};
  helper.markdownIt = true;
  helper.whiteList = info => whiteListed.push([featureName, info]);
  helper.registerInline = deprecate(featureName, "registerInline");
  helper.replaceBlock = deprecate(featureName, "replaceBlock");
  helper.addPreProcessor = deprecate(featureName, "addPreProcessor");
  helper.inlineReplace = deprecate(featureName, "inlineReplace");
  helper.postProcessTag = deprecate(featureName, "postProcessTag");
  helper.inlineRegexp = deprecate(featureName, "inlineRegexp");
  helper.inlineBetween = deprecate(featureName, "inlineBetween");
  helper.postProcessText = deprecate(featureName, "postProcessText");
  helper.onParseNode = deprecate(featureName, "onParseNode");
  helper.registerBlock = deprecate(featureName, "registerBlock");
  // hack to allow moving of getOptions
  helper.getOptions = () => getOptions.f();

  helper.registerOptions = callback => {
    optionCallbacks.push([featureName, callback]);
  };

  helper.registerPlugin = callback => {
    pluginCallbacks.push([featureName, callback]);
  };

  return helper;
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
function setupBlockBBCode(md) {
  md.block.bbcode = { ruler: new Ruler() };
}

function setupInlineBBCode(md) {
  md.inline.bbcode = { ruler: new Ruler() };
}

function setupTextPostProcessRuler(md) {
  const TextPostProcessRuler = requirejs(
    "pretty-text/engines/discourse-markdown/text-post-process"
  ).TextPostProcessRuler;
  md.core.textPostProcess = { ruler: new TextPostProcessRuler() };
}

function renderHoisted(tokens, idx, options) {
  const content = tokens[idx].content;
  if (content && content.length > 0) {
    let id = guid();
    options.discourse.hoisted[id] = tokens[idx].content;
    return id;
  } else {
    return "";
  }
}

function setupUrlDecoding(md) {
  // this fixed a subtle issue where %20 is decoded as space in
  // automatic urls
  md.utils.lib.mdurl.decode.defaultChars = ";/?:@&=+$,# ";
}

function setupHoister(md) {
  md.renderer.rules.html_raw = renderHoisted;
}

export function extractDataAttribute(str) {
  let sep = str.indexOf("=");
  if (sep === -1) {
    return null;
  }

  const key = `data-${str.substr(0, sep)}`.toLowerCase();
  if (!/^[A-Za-z]+[\w\-\:\.]*$/.test(key)) {
    return null;
  }

  const value = str.substr(sep + 1);
  return [key, value];
}

// videoHTML and audioHTML follow the same HTML syntax
// as oneboxer.rb when dealing with these formats
function videoHTML(token, opts) {
  const src = token.attrGet("src");
  const origSrc = token.attrGet("data-orig-src");
  const preloadType = opts.secureMedia ? "none" : "metadata";
  return `<div class="video-container">
    <video width="100%" height="100%" preload="${preloadType}" controls>
      <source src="${src}" data-orig-src="${origSrc}">
      <a href="${src}">${src}</a>
    </video>
  </div>`;
}

function audioHTML(token, opts) {
  const src = token.attrGet("src");
  const origSrc = token.attrGet("data-orig-src");
  const preloadType = opts.secureMedia ? "none" : "metadata";
  return `<audio preload="${preloadType}" controls>
    <source src="${src}" data-orig-src="${origSrc}">
    <a href="${src}">${src}</a>
  </audio>`;
}

const IMG_SIZE_REGEX = /^([1-9]+[0-9]*)x([1-9]+[0-9]*)(\s*,\s*(x?)([1-9][0-9]{0,2}?)([%x]?))?$/;
function renderImageOrPlayableMedia(tokens, idx, options, env, slf) {
  const token = tokens[idx];
  const alt = slf.renderInlineAsText(token.children, options, env);
  const split = alt.split("|");
  const altSplit = [];

  // markdown-it supports returning HTML instead of continuing to render the current token
  // see https://github.com/markdown-it/markdown-it/blob/master/docs/architecture.md#renderer
  // handles |video and |audio alt transformations for image tags
  const mediaOpts = {
    secureMedia: options.discourse.limitedSiteSettings.secureMedia
  };
  if (split[1] === "video") {
    return videoHTML(token, mediaOpts);
  } else if (split[1] === "audio") {
    return audioHTML(token, mediaOpts);
  }

  // parsing ![myimage|500x300]() or ![myimage|75%]() or ![myimage|500x300, 75%]
  for (let i = 0, match, data; i < split.length; ++i) {
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

      if (options.discourse.previewing && match[6] !== "x" && match[4] !== "x")
        token.attrs.push(["class", "resizable"]);
    } else if ((data = extractDataAttribute(split[i]))) {
      token.attrs.push(data);
    } else {
      altSplit.push(split[i]);
    }
  }

  token.attrs[token.attrIndex("alt")][1] = altSplit.join("|");
  return slf.renderToken(tokens, idx, options);
}

// we have taken over the ![]() syntax in markdown to
// be able to render a video or audio URL as well as the
// image using |video and |audio in the text inside []
function setupImageAndPlayableMediaRenderer(md) {
  md.renderer.rules.image = renderImageOrPlayableMedia;
}

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

function setupAttachments(md) {
  md.renderer.rules.link_open = renderAttachment;
}

let Helpers;

export function setup(opts, siteSettings, state) {
  if (opts.setup) {
    return;
  }

  // we got to require this late cause bundle is not loaded in pretty-text
  Helpers =
    Helpers || requirejs("pretty-text/engines/discourse-markdown/helpers");

  opts.markdownIt = true;

  let optionCallbacks = [];
  let pluginCallbacks = [];

  // ideally I would like to change the top level API a bit, but in the mean time this will do
  let getOptions = {
    f: () => opts
  };

  const check = /discourse-markdown\/|markdown-it\//;
  let features = [];
  let whiteListed = [];

  Object.keys(require._eak_seen).forEach(entry => {
    if (check.test(entry)) {
      const module = requirejs(entry);
      if (module && module.setup) {
        const featureName = entry.split("/").reverse()[0];
        features.push(featureName);
        module.setup(
          createHelper(
            featureName,
            opts,
            optionCallbacks,
            pluginCallbacks,
            getOptions,
            whiteListed
          )
        );
      }
    }
  });

  Object.entries(state.whiteListed || {}).forEach(entry => {
    whiteListed.push(entry);
  });

  optionCallbacks.forEach(([, callback]) => {
    callback(opts, siteSettings, state);
  });

  // enable all features by default
  features.forEach(feature => {
    if (!opts.features.hasOwnProperty(feature)) {
      opts.features[feature] = true;
    }
  });

  let copy = {};
  Object.keys(opts).forEach(entry => {
    copy[entry] = opts[entry];
    delete opts[entry];
  });

  copy.helpers = {
    textReplace: Helpers.textReplace
  };

  opts.discourse = copy;
  getOptions.f = () => opts.discourse;

  opts.discourse.limitedSiteSettings = {
    secureMedia: siteSettings.secure_media
  };

  opts.engine = window.markdownit({
    discourse: opts.discourse,
    html: true,
    breaks: opts.discourse.features.newline,
    xhtmlOut: false,
    linkify: siteSettings.enable_markdown_linkify,
    typographer: siteSettings.enable_markdown_typographer
  });

  const quotation_marks = siteSettings.markdown_typographer_quotation_marks;
  if (quotation_marks) {
    opts.engine.options.quotes = quotation_marks.split("|");
  }

  opts.engine.linkify.tlds(
    (siteSettings.markdown_linkify_tlds || "").split("|")
  );

  setupUrlDecoding(opts.engine);
  setupHoister(opts.engine);
  setupImageAndPlayableMediaRenderer(opts.engine);
  setupAttachments(opts.engine);
  setupBlockBBCode(opts.engine);
  setupInlineBBCode(opts.engine);
  setupTextPostProcessRuler(opts.engine);

  pluginCallbacks.forEach(([feature, callback]) => {
    if (opts.discourse.features[feature]) {
      opts.engine.use(callback);
    }
  });

  // top level markdown it notifier
  opts.markdownIt = true;
  opts.setup = true;

  if (!opts.discourse.sanitizer || !opts.sanitizer) {
    const whiteLister = new WhiteLister(opts.discourse);

    whiteListed.forEach(([feature, info]) => {
      whiteLister.whiteListFeature(feature, info);
    });

    opts.sanitizer = opts.discourse.sanitizer = !!opts.discourse.sanitize
      ? a => sanitize(a, whiteLister)
      : a => a;
  }
}

export function cook(raw, opts) {
  // we still have to hoist html_raw nodes so they bypass the whitelister
  // this is the case for oneboxes
  let hoisted = {};

  opts.discourse.hoisted = hoisted;

  const rendered = opts.engine.render(raw);
  let cooked = opts.discourse.sanitizer(rendered).trim();

  const keys = Object.keys(hoisted);
  if (keys.length) {
    let found = true;

    const unhoist = function(key) {
      cooked = cooked.replace(new RegExp(key, "g"), function() {
        found = true;
        return hoisted[key];
      });
    };

    while (found) {
      found = false;
      keys.forEach(unhoist);
    }
  }

  delete opts.discourse.hoisted;
  return cooked;
}
