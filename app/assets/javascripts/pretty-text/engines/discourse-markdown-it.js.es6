import { default as WhiteLister } from "pretty-text/white-lister";
import { sanitize } from "pretty-text/sanitizer";
import guid from "pretty-text/guid";

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

const IMG_SIZE_REGEX = /^([1-9]+[0-9]*)x([1-9]+[0-9]*)(\s*,\s*([1-9][0-9]?)%)?$/;
function renderImage(tokens, idx, options, env, slf) {
  var token = tokens[idx];

  let alt = slf.renderInlineAsText(token.children, options, env);

  let split = alt.split("|");
  if (split.length > 1) {
    let match;
    let info = split.splice(split.length - 1)[0];

    if ((match = info.match(IMG_SIZE_REGEX))) {
      if (match[1] && match[2]) {
        alt = split.join("|");

        let width = match[1];
        let height = match[2];

        if (match[4]) {
          let percent = parseFloat(match[4]) / 100.0;
          width = parseInt(width * percent);
          height = parseInt(height * percent);
        }

        if (token.attrIndex("width") === -1) {
          token.attrs.push(["width", width]);
        }

        if (token.attrIndex("height") === -1) {
          token.attrs.push(["height", height]);
        }
      }
    }
  }

  token.attrs[token.attrIndex("alt")][1] = alt;
  return slf.renderToken(tokens, idx, options);
}

function setupImageDimensions(md) {
  md.renderer.rules.image = renderImage;
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

  opts.engine = window.markdownit({
    discourse: opts.discourse,
    html: true,
    breaks: opts.discourse.features.newline,
    xhtmlOut: false,
    linkify: siteSettings.enable_markdown_linkify,
    typographer: siteSettings.enable_markdown_typographer
  });

  opts.engine.linkify.tlds(
    (siteSettings.markdown_linkify_tlds || "").split("|")
  );

  setupUrlDecoding(opts.engine);
  setupHoister(opts.engine);
  setupImageDimensions(opts.engine);
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
