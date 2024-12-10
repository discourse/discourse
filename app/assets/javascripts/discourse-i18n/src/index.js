if (window.I18n) {
  throw new Error(
    "I18n already defined, discourse-i18n unexpectedly loaded twice!"
  );
}

import * as Cardinals from "make-plural/cardinals";

// The placeholder format. Accepts `{{placeholder}}` and `%{placeholder}`.
const PLACEHOLDER = /(?:\{\{|%\{)(.*?)(?:\}\}?)/gm;
const SEPARATOR = ".";

export class I18n {
  // Set default locale to english
  defaultLocale = "en";

  // Set current locale to null
  locale = null;
  fallbackLocale = null;
  translations = null;
  extras = null;
  noFallbacks = false;
  testing = false;
  verbose = false;
  verboseIndicies = new Map();

  pluralizationRules = Cardinals;

  translate = (scope, options) => {
    return this.verbose
      ? this._verboseTranslate(scope, options)
      : this._translate(scope, options);
  };

  // shortcut
  t = this.translate;

  currentLocale() {
    return this.locale || this.defaultLocale;
  }

  get currentBcp47Locale() {
    return this.currentLocale().replace("_", "-");
  }

  get pluralizationNormalizedLocale() {
    if (this.currentLocale() === "pt") {
      return "pt_PT";
    }
    return this.currentLocale().replace(/[_-].*/, "");
  }

  enableVerboseLocalization() {
    this.noFallbacks = true;
    this.verbose = true;
  }

  enableVerboseLocalizationSession() {
    sessionStorage.setItem("verbose_localization", "true");
    this.enableVerboseLocalization();
    return "Verbose localization is enabled. Close the browser tab to turn it off. Reload the page to see the translation keys.";
  }

  _translate(scope, options) {
    options = this.prepareOptions(options);
    options.needsPluralization = typeof options.count === "number";
    options.ignoreMissing = !this.noFallbacks;

    let translation = this.findTranslation(scope, options);

    if (!this.noFallbacks) {
      if (!translation && this.fallbackLocale) {
        options.locale = this.fallbackLocale;
        translation = this.findTranslation(scope, options);
      }

      options.ignoreMissing = false;

      if (!translation && this.currentLocale() !== this.defaultLocale) {
        options.locale = this.defaultLocale;
        translation = this.findTranslation(scope, options);
      }

      if (!translation && this.currentLocale() !== "en") {
        options.locale = "en";
        translation = this.findTranslation(scope, options);
      }
    }

    try {
      return this.interpolate(translation, options, scope);
    } catch (error) {
      if (error instanceof I18nMissingInterpolationArgument) {
        throw error;
      } else {
        return (
          options.translatedFallback ||
          this.missingTranslation(scope, null, options)
        );
      }
    }
  }

  toNumber(number, options) {
    options = this.prepareOptions(options, this.lookup("number.format"), {
      precision: 3,
      separator: SEPARATOR,
      delimiter: ",",
      strip_insignificant_zeros: false,
    });

    let negative = number < 0;
    let string = Math.abs(number).toFixed(options.precision).toString();
    let parts = string.split(SEPARATOR);
    let buffer = [];
    let formattedNumber;

    number = parts[0];

    while (number.length > 0) {
      let pos = Math.max(0, number.length - 3);
      buffer.unshift(number.slice(pos, pos + 3));
      number = number.slice(0, -3);
    }

    formattedNumber = buffer.join(options.delimiter);

    if (options.precision > 0) {
      formattedNumber += options.separator + parts[1];
    }

    if (negative) {
      formattedNumber = "-" + formattedNumber;
    }

    if (options.strip_insignificant_zeros) {
      let regex = {
        separator: new RegExp(options.separator.replace(/\./, "\\.") + "$"),
        zeros: /0+$/,
      };

      formattedNumber = formattedNumber
        .replace(regex.zeros, "")
        .replace(regex.separator, "");
    }

    return formattedNumber;
  }

  toHumanSize(number, options) {
    let kb = 1024;
    let size = number;
    let iterations = 0;
    let unit, precision;

    while (size >= kb && iterations < 4) {
      size = size / kb;
      iterations += 1;
    }

    if (iterations === 0) {
      unit = this.t("number.human.storage_units.units.byte", { count: size });
      precision = 0;
    } else {
      unit = this.t(
        "number.human.storage_units.units." +
          [null, "kb", "mb", "gb", "tb"][iterations]
      );
      precision = size - Math.floor(size) === 0 ? 0 : 1;
    }

    options = this.prepareOptions(options, {
      precision,
      format: this.t("number.human.storage_units.format"),
      delimiter: "",
    });

    number = this.toNumber(size, options);
    number = options.format.replace("%u", unit).replace("%n", number);

    return number;
  }

  pluralize(translation, scope, options) {
    if (typeof translation !== "object") {
      return translation;
    }

    options = this.prepareOptions(options);
    let count = options.count.toString();

    let pluralizer = this.pluralizer(
      options.locale || this.pluralizationNormalizedLocale
    );
    let key = pluralizer(Math.abs(count));
    let keys = typeof key === "object" && key instanceof Array ? key : [key];
    let message = this.findAndTranslateValidNode(keys, translation);

    if (message !== null || options.ignoreMissing) {
      return message;
    }

    return this.missingTranslation(scope, keys[0]);
  }

  pluralizer(locale) {
    return this.pluralizationRules[locale] ?? this.pluralizationRules["en"];
  }

  listJoiner(listOfStrings, delimiter) {
    if (listOfStrings.length === 1) {
      return listOfStrings[0];
    }

    if (listOfStrings.length === 2) {
      return listOfStrings[0] + " " + delimiter + " " + listOfStrings[1];
    }

    let lastString = listOfStrings.pop();
    return listOfStrings.concat(delimiter).join(`, `) + " " + lastString;
  }

  interpolate(message, options, scope) {
    options = this.prepareOptions(options);
    let matches = message.match(PLACEHOLDER);
    let placeholder, value, name;

    if (!matches) {
      return message;
    }

    for (let i = 0; (placeholder = matches[i]); i++) {
      name = placeholder.replace(PLACEHOLDER, "$1");

      if (typeof options[name] === "string") {
        // The dollar sign (`$`) is a special replace pattern, and `$&` inserts
        // the matched string. Thus dollars signs need to be escaped with the
        // special pattern `$$`, which inserts a single `$`.
        // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace#Specifying_a_string_as_a_parameter
        value = options[name].replace(/\$/g, "$$$$");
      } else {
        value = options[name];
      }

      if (!this.isValidNode(options, name)) {
        value = "[missing " + placeholder + " value]";

        if (this.testing) {
          throw new I18nMissingInterpolationArgument(`${scope}: ${value}`);
        }
      }

      let regex = new RegExp(
        placeholder.replace(/\{/gm, "\\{").replace(/\}/gm, "\\}")
      );

      message = message.replace(regex, value);
    }

    return message;
  }

  findTranslation(scope, options) {
    let translation = this.lookup(scope, options);

    if (translation && options.needsPluralization) {
      translation = this.pluralize(translation, scope, options);
    }

    return translation;
  }

  findAndTranslateValidNode(keys, translation) {
    for (let key of keys) {
      if (this.isValidNode(translation, key)) {
        return translation[key];
      }
    }

    return null;
  }

  lookup(scope, options = {}) {
    let translations = this.prepareOptions(this.translations);
    let locale = options.locale || this.currentLocale();
    let messages = translations[locale] || {};
    let currentScope;

    options = this.prepareOptions(options);

    if (typeof scope === "object") {
      scope = scope.join(SEPARATOR);
    }

    if (options.scope) {
      scope = options.scope.toString() + SEPARATOR + scope;
    }

    let originalScope = scope;
    scope = scope.split(SEPARATOR);

    if (scope.length > 0 && scope[0] !== "js") {
      scope.unshift("js");
    }

    while (messages && scope.length > 0) {
      currentScope = scope.shift();
      messages = messages[currentScope];
    }

    if (messages === undefined && this.extras && this.extras[locale]) {
      messages = this.extras[locale];
      scope = originalScope.split(SEPARATOR);

      while (messages && scope.length > 0) {
        currentScope = scope.shift();
        messages = messages[currentScope];
      }
    }

    if (messages === undefined) {
      messages = options.defaultValue;
    }

    return messages;
  }

  missingTranslation(scope, key, options) {
    let message = "[" + this.currentLocale() + SEPARATOR + scope;

    if (key) {
      message += SEPARATOR + key;
    }

    if (options && options.hasOwnProperty("count")) {
      message += " count=" + JSON.stringify(options.count);
    }

    return message + "]";
  }

  // Merge several hash options, checking if value is set before
  // overwriting any value. The precedence is from left to right.
  //
  //   I18n.prepareOptions({name: "John Doe"}, {name: "Mary Doe", role: "user"});
  //   #=> {name: "John Doe", role: "user"}
  //
  prepareOptions(...args) {
    let options = {};
    let count = args.length;
    let opts;

    for (let i = 0; i < count; i++) {
      opts = arguments[i];

      if (!opts) {
        continue;
      }

      for (let key in opts) {
        if (!this.isValidNode(options, key)) {
          options[key] = opts[key];
        }
      }
    }

    return options;
  }

  isValidNode(obj, node) {
    return obj[node] !== null && obj[node] !== undefined;
  }

  messageFormat(key, options) {
    const message = this._mfMessages?.hasMessage(
      key,
      this._mfMessages.locale,
      this._mfMessages.defaultLocale
    );
    if (!message) {
      return "Missing Key: " + key;
    }
    try {
      return this._mfMessages.get(key, options);
    } catch (err) {
      return err.message;
    }
  }

  _verboseTranslate(scope, options) {
    const result = this._translate(scope, options);
    let i = this.verboseIndicies.get(scope);
    if (!i) {
      i = this.verboseIndicies.size + 1;
      this.verboseIndicies.set(scope, i);
    }
    let message = `Translation #${i}: ${scope}`;
    if (options && Object.keys(options).length > 0) {
      message += `, parameters: ${JSON.stringify(options)}`;
    }
    // eslint-disable-next-line no-console
    console.info(message);
    return `${result} (#${i})`;
  }
}

export class I18nMissingInterpolationArgument extends Error {
  constructor(message) {
    super(message);
    this.name = "I18nMissingInterpolationArgument";
  }
}

// Export a default/global instance
export default globalThis.I18n = new I18n();

export const i18n = globalThis.I18n.t;
