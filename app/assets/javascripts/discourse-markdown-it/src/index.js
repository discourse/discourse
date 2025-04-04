import { cook as cookIt } from "./engine";
import DEFAULT_FEATURES from "./features";
import buildOptions from "./options";
import setup from "./setup";

function NOOP(ident) {
  return ident;
}

export default class DiscourseMarkdownIt {
  static withDefaultFeatures() {
    return this.withFeatures(DEFAULT_FEATURES);
  }

  static withCustomFeatures(features) {
    return this.withFeatures([...DEFAULT_FEATURES, ...features]);
  }

  static withFeatures(features) {
    const withOptions = (options) => this.withOptions(features, options);
    return { withOptions };
  }

  static withOptions(features, rawOptions) {
    const { options, siteSettings, state } = buildOptions(rawOptions);

    // note, this will mutate options due to the way the API is designed
    // may need a refactor
    setup(features, options, siteSettings, state);

    return new DiscourseMarkdownIt(options);
  }

  static minimal() {
    return this.withFeatures([]).withOptions({ siteSettings: {} });
  }

  constructor(options) {
    if (!options.setup) {
      throw new Error(
        "Cannot construct DiscourseMarkdownIt from raw options, " +
          "use DiscourseMarkdownIt.withOptions() instead"
      );
    }

    this.options = options;
  }

  disableSanitizer() {
    this.options.sanitizer = this.options.discourse.sanitizer = NOOP;
  }

  cook(raw) {
    if (raw === undefined || raw === null) {
      return "";
    }

    raw = raw.toString();

    if (!raw || raw.length === 0) {
      return "";
    }

    let result;
    result = cookIt(raw, this.options);
    return result ? result : "";
  }

  parse(markdown, env = {}) {
    return this.options.engine.parse(markdown, env);
  }

  sanitize(html) {
    return this.options.sanitizer(html).trim();
  }

  get linkify() {
    return this.options.engine.linkify;
  }
}
