import { textReplace } from "pretty-text/text-replace";
import deprecated from "discourse/lib/deprecated";
import { cloneJSON } from "discourse/lib/object";
import makeEngine, { cook } from "./engine";

// note, this will mutate options due to the way the API is designed
// may need a refactor
export default function setupIt(features, options, siteSettings, state) {
  Setup.run(features, options, siteSettings, state);
}

class Setup {
  static run(features, options, siteSettings, state) {
    if (options.setup) {
      // Already setup
      return;
    }

    const setup = new Setup(options);

    features.sort((a, b) => a.priority - b.priority);

    for (const feature of features) {
      setup.#setupFeature(feature.id, feature.setup);
    }

    for (const entry of Object.entries(state.allowListed ?? {})) {
      setup.allowList(entry);
    }

    setup.#runOptionsCallbacks(siteSettings, state);

    setup.#enableMarkdownFeatures();

    setup.#finalizeGetOptions(siteSettings);

    setup.#makeEngine();

    setup.#buildCookFunctions();
  }

  #context;
  #options;

  #allowListed = [];
  #customMarkdownCookFunctionCallbacks = [];
  #loadedFeatures = [];
  #optionCallbacks = [];
  #pluginCallbacks = [];

  constructor(options) {
    options.markdownIt = true;

    this.#options = options;

    // hack to allow moving of getOptions – see #finalizeGetOptions
    this.#context = { options };
  }

  allowList(entry) {
    this.#allowListed.push(entry);
  }

  registerOptions(entry) {
    this.#optionCallbacks.push(entry);
  }

  registerPlugin(entry) {
    this.#pluginCallbacks.push(entry);
  }

  buildCookFunction(entry) {
    this.#customMarkdownCookFunctionCallbacks.push(entry);
  }

  #setupFeature(featureName, callback) {
    // When we provide the API object to the setup callback, we expect them to
    // make use of it synchronously. However, it is possible that the could
    // close over the API object, intentionally or unintentionally, and cause
    // memory leaks or unexpectedly call API methods at a later time with
    // unpredictable results. This make sure to "gut" the API object after the
    // callback is executed so that it cannot leak memory or be used later.
    let loaned = this;

    const doSetup = (methodName, ...args) => {
      if (loaned === null) {
        throw new Error(
          `${featureName}: ${methodName} can only be called during setup()!`
        );
      }

      if (loaned[methodName]) {
        return loaned[methodName](...args);
      }
    };

    callback(new API(featureName, this.#context, doSetup));

    this.#loadedFeatures.push(featureName);

    // revoke access to the Setup object
    loaned = null;
  }

  #runOptionsCallbacks(siteSettings, state) {
    this.#drain(this.#optionCallbacks, ([, callback]) =>
      callback(this.#options, siteSettings, state)
    );
  }

  #enableMarkdownFeatures({ features, featuresOverride } = this.#options) {
    // TODO: `options.features` could in theory contain additional keys for
    // features that aren't loaded. The way the previous code was written
    // incidentally means we would iterate over a super set of both. To be
    // pedantic we kept that behavior here, but I'm not sure if that's really
    // necessary.
    const allFeatures = new Set([
      ...this.#drain(this.#loadedFeatures),
      ...Object.keys(features),
    ]);

    if (featuresOverride) {
      for (const feature of allFeatures) {
        features[feature] = featuresOverride.includes(feature);
      }
    } else {
      // enable all features by default
      for (let feature of allFeatures) {
        features[feature] ??= true;
      }
    }
  }

  #finalizeGetOptions(siteSettings) {
    // This is weird but essentially we want to remove `options.*` in-place
    // into `options.discourse.*`, then, we want to change `context.options`
    // to point at `options.discourse`. This ensures features that held onto
    // the API object during setup will continue to get the right stuff when
    // they call `getOptions()`.
    const options = this.#options;
    const discourse = {};

    for (const [key, value] of Object.entries(options)) {
      discourse[key] = value;
      delete options[key];
    }

    discourse.helpers = { textReplace };

    discourse.limitedSiteSettings = {
      secureUploads: siteSettings.secure_uploads,
      enableDiffhtmlPreview: siteSettings.enable_diffhtml_preview,
      traditionalMarkdownLinebreaks:
        siteSettings.traditional_markdown_linebreaks,
      enableMarkdownLinkify: siteSettings.enable_markdown_linkify,
      enableMarkdownTypographer: siteSettings.enable_markdown_typographer,
      markdownTypographerQuotationMarks:
        siteSettings.markdown_typographer_quotation_marks,
      markdownLinkifyTlds: siteSettings.markdown_linkify_tlds,
    };

    this.#context.options = options.discourse = discourse;
  }

  #makeEngine() {
    const options = this.#options;
    const { discourse } = options;
    const { markdownItRules, limitedSiteSettings } = discourse;
    const {
      enableMarkdownLinkify,
      enableMarkdownTypographer,
      traditionalMarkdownLinebreaks,
    } = limitedSiteSettings;

    options.allowListed = this.#drain(this.#allowListed);
    options.pluginCallbacks = this.#drain(this.#pluginCallbacks);

    const markdownItOptions = {
      discourse,
      html: true,
      breaks: !traditionalMarkdownLinebreaks,
      xhtmlOut: false,
      linkify: enableMarkdownLinkify,
      typographer: enableMarkdownTypographer,
    };

    makeEngine(options, markdownItOptions, markdownItRules);
  }

  #buildCookFunctions() {
    const options = this.#options;

    // the callback argument we pass to the callbacks
    let callbackArg = (engineOptions, afterBuild) =>
      afterBuild(this.#buildCookFunction(engineOptions, options));

    this.#drain(this.#customMarkdownCookFunctionCallbacks, ([, callback]) => {
      callback(options, callbackArg);
    });
  }

  #buildCookFunction(engineOptions, defaultOptions) {
    // everything except the engine for opts can just point to the other
    // opts references, they do not change and we don't need to worry about
    // mutating them. note that this may need to be updated when additional
    // opts are added to the pipeline
    const options = {};
    options.allowListed = defaultOptions.allowListed;
    options.pluginCallbacks = defaultOptions.pluginCallbacks;
    options.sanitizer = defaultOptions.sanitizer;

    // everything from the discourse part of defaultOptions can be cloned except
    // the features, because these can be a limited subset and we don't want to
    // change the original object reference
    const features = cloneJSON(defaultOptions.discourse.features);
    options.discourse = {
      ...defaultOptions.discourse,
      features,
    };

    this.#enableMarkdownFeatures({
      features,
      featuresOverride: engineOptions.featuresOverride,
    });

    const markdownItOptions = {
      discourse: options.discourse,
      html: defaultOptions.engine.options.html,
      breaks: defaultOptions.engine.options.breaks,
      xhtmlOut: defaultOptions.engine.options.xhtmlOut,
      linkify: defaultOptions.engine.options.linkify,
      typographer: defaultOptions.engine.options.typographer,
    };

    makeEngine(options, markdownItOptions, engineOptions.markdownItRules);

    return function customCookFunction(raw) {
      return cook(raw, options);
    };
  }

  #drain(items, callback) {
    if (callback) {
      let item = items.shift();

      while (item) {
        callback(item);
        item = items.shift();
      }
    } else {
      const cloned = [...items];
      items.length = 0;
      return cloned;
    }
  }
}

class API {
  #name;
  #context;
  #setup;
  #deprecate;

  constructor(featureName, context, setup) {
    this.#name = featureName;
    this.#context = context;
    this.#setup = setup;
    this.#deprecate = (methodName, ...args) => {
      if (window.console && window.console.log) {
        window.console.log(
          featureName +
            ": " +
            methodName +
            " is deprecated, please use the new markdown it APIs"
        );
      }

      return setup(methodName, ...args);
    };
  }

  get markdownIt() {
    return true;
  }

  // this the only method we expect to be called post-setup()
  getOptions() {
    return this.#context.options;
  }

  allowList(info) {
    this.#setup("allowList", [this.#name, info]);
  }

  whiteList(info) {
    deprecated("`whiteList` has been replaced with `allowList`", {
      since: "2.6.0.beta.4",
      dropFrom: "2.7.0",
      id: "discourse.markdown-it.whitelist",
    });

    this.allowList(info);
  }

  registerOptions(callback) {
    this.#setup("registerOptions", [this.#name, callback]);
  }

  registerPlugin(callback) {
    this.#setup("registerPlugin", [this.#name, callback]);
  }

  buildCookFunction(callback) {
    this.#setup("buildCookFunction", [this.#name, callback]);
  }

  // deprecate methods – "deprecate" is a bit of a misnomer here since the
  // methods don't actually do anything anymore

  registerInline() {
    this.#deprecate("registerInline");
  }

  replaceBlock() {
    this.#deprecate("replaceBlock");
  }

  addPreProcessor() {
    this.#deprecate("addPreProcessor");
  }

  inlineReplace() {
    this.#deprecate("inlineReplace");
  }

  postProcessTag() {
    this.#deprecate("postProcessTag");
  }

  inlineRegexp() {
    this.#deprecate("inlineRegexp");
  }

  inlineBetween() {
    this.#deprecate("inlineBetween");
  }

  postProcessText() {
    this.#deprecate("postProcessText");
  }

  onParseNode() {
    this.#deprecate("onParseNode");
  }

  registerBlock() {
    this.#deprecate("registerBlock");
  }
}
