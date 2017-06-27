import { default as WhiteLister, whiteListFeature } from 'pretty-text/white-lister';
import { sanitize } from 'pretty-text/sanitizer';
import guid from 'pretty-text/guid';

function deprecate(feature, name){
  return function() {
    if (window.console && window.console.log) {
      window.console.log(feature + ': ' + name + ' is deprecated, please use the new markdown it APIs');
    }
  };
}

function createHelper(featureName, opts, optionCallbacks, pluginCallbacks, getOptions) {
  let helper = {};
  helper.markdownIt = true;
  helper.whiteList = info => whiteListFeature(featureName, info);
  helper.registerInline = deprecate(featureName,'registerInline');
  helper.replaceBlock = deprecate(featureName,'replaceBlock');
  helper.addPreProcessor = deprecate(featureName,'addPreProcessor');
  helper.inlineReplace = deprecate(featureName,'inlineReplace');
  helper.postProcessTag = deprecate(featureName,'postProcessTag');
  helper.inlineRegexp = deprecate(featureName,'inlineRegexp');
  helper.inlineBetween = deprecate(featureName,'inlineBetween');
  helper.postProcessText = deprecate(featureName,'postProcessText');
  helper.onParseNode = deprecate(featureName,'onParseNode');
  helper.registerBlock = deprecate(featureName,'registerBlock');
  // hack to allow moving of getOptions
  helper.getOptions = () => getOptions.f();

  helper.registerOptions = (callback) => {
    optionCallbacks.push([featureName, callback]);
  };

  helper.registerPlugin = (callback) => {
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

  push(name, rule) {
    this.rules.push({name, rule});
  }
}

// block bb code ruler for parsing of quotes / code / polls
function setupBlockBBCode(md) {
  md.block.bbcode_ruler = new Ruler();
}

function setupInlineBBCode(md) {
  md.inline.bbcode_ruler = new Ruler();
}

function renderHoisted(tokens, idx, options) {
  const content = tokens[idx].content;
  if (content && content.length > 0) {
    let id = guid();
    options.discourse.hoisted[id] = tokens[idx].content;
    return id;
  } else {
    return '';
  }
}

function setupHoister(md) {
  md.renderer.rules.html_raw = renderHoisted;
}

export function setup(opts, siteSettings, state) {
  if (opts.setup) {
    return;
  }

  opts.markdownIt = true;

  let optionCallbacks = [];
  let pluginCallbacks = [];

  // ideally I would like to change the top level API a bit, but in the mean time this will do
  let getOptions = {
    f: () => opts
  };

  const check = /discourse-markdown\/|markdown-it\//;
  let features = [];

  Object.keys(require._eak_seen).forEach(entry => {
    if (check.test(entry)) {
      const module = require(entry);
      if (module && module.setup) {

        const featureName = entry.split('/').reverse()[0];
        features.push(featureName);
        module.setup(createHelper(featureName, opts, optionCallbacks, pluginCallbacks, getOptions));
      }
    }
  });

  optionCallbacks.forEach(([,callback])=>{
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

  opts.discourse = copy;
  getOptions.f = () => opts.discourse;

  opts.engine = window.markdownit({
    discourse: opts.discourse,
    html: true,
    breaks: opts.discourse.features.newline,
    xhtmlOut: false,
    linkify: true,
    typographer: siteSettings.enable_markdown_typographer
  });

  setupHoister(opts.engine);
  setupBlockBBCode(opts.engine);
  setupInlineBBCode(opts.engine);

  pluginCallbacks.forEach(([feature, callback])=>{
    if (opts.discourse.features[feature]) {
      opts.engine.use(callback);
    }
  });

  // top level markdown it notifier
  opts.markdownIt = true;
  opts.setup = true;

  if (!opts.discourse.sanitizer) {
    const whiteLister = new WhiteLister(opts.discourse);
    opts.sanitizer = opts.discourse.sanitizer = (!!opts.discourse.sanitize) ? a=>sanitize(a, whiteLister) : a=>a;
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
