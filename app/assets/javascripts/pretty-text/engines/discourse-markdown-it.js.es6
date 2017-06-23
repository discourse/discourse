import { default as WhiteLister, whiteListFeature } from 'pretty-text/white-lister';
import { sanitize } from 'pretty-text/sanitizer';

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
    typographer: false
  });

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
    opts.sanitizer = opts.discourse.sanitizer = (!!opts.discourse.sanitize) ? sanitize : a=>a;
  }
}

export function cook(raw, opts) {
  const whiteLister = new WhiteLister(opts.discourse);
  return opts.discourse.sanitizer(opts.engine.render(raw), whiteLister).trim();
}
