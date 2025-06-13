import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import curryComponent from "ember-curry-component";
import TranslationPlaceholder from "discourse/components/translation-placeholder";
import uniqueId from "discourse/helpers/unique-id";
import { isProduction } from "discourse/lib/environment";
import I18n, { i18n, I18nMissingInterpolationArgument } from "discourse-i18n";

/**
 * Provides the ability to interpolate both strings and components into translatable strings.
 * This component allows for complex i18n scenarios where you need to embed interactive
 * components within translated text.
 *
 * If you don't require this functionality, use the standard i18n() function.
 *
 * @component Translation
 *
 * @template Usage example:
 * ```gjs
 * // Translation key: "some.translation.key" = "Welcome, %{username}! The date is %{shortdate}!"
 * <Translation
 *   @key="some.translation.key"
 *   @options={{hash shortdate=shortDate}}
 *   as |Placeholder|
 * >
 *   <Placeholder @name="username">
 *     <UserLink @user={{user}}>{{user.username}}</UserLink>
 *   </Placeholder>
 * </Translation>
 * ```
 *
 * @param {String} key - The i18n translation key to use
 * @param {Object} [options] - Hash of options to pass to the i18n function for string interpolation
 */
export default class Translation extends Component {
  /**
   * Set to @options, or {} if that param wasn't passed.
   *
   * @type {Object}
   **/
  _optionsArgs;

  /**
   * A map of placeholder keys to their unique identifiers.
   *
   * @type {Map<String, String>}
   */
  _placeholderKeys = new Map();

  /**
   * A map of placeholder keys to their corresponding DOM elements.
   *
   * @type {Map<String, HTMLElement>}
   */
  _placeholderElements = new Map();

  /**
   * A map of placeholder keys to their appearance in the translation string.
   *
   * @type {Map<String, String>}
   */
  _placeholderAppearance = new Map();

  /**
   * Tracks which placeholders have been rendered.
   *
   * @type {Array<String>}
   */
  _renderedPlaceholders = [];

  /**
   * Processes the translation string and returns an array of text segments and
   * placeholder elements that can be rendered in the template.
   *
   * @returns {Array<String|HTMLElement>} Array of text segments and placeholder elements
   */
  get textAndPlaceholders() {
    this._optionsArg = this.args.options || {};

    // Find all of the placeholders in the string we're looking at.
    const message = I18n.findTranslationWithFallback(this.args.key, {
      ...this._optionsArg,
    });
    this._placeholderAppearance = I18n.findPlaceholders(message);

    // We only need to keep the placeholders that aren't being handled by those passed in @options.
    Object.keys(this._optionsArg).forEach((stringPlaceholder) =>
      this._placeholderAppearance.delete(stringPlaceholder)
    );

    this._placeholderAppearance.forEach(
      (placeholderAppearances, placeholderName) => {
        this._placeholderKeys.set(
          placeholderName,
          `__PLACEHOLDER__${placeholderName}__${uniqueId()}__`
        );
        this._placeholderElements.set(
          placeholderName,
          placeholderAppearances.map(() => document.createElement("span"))
        );
      }
    );

    const text = i18n(this.args.key, {
      ...Object.fromEntries(this._placeholderKeys),
      ...this._optionsArg,
    });

    // Bail early if there were no placeholders we need to handle.
    if (this._placeholderAppearance.size === 0) {
      return [text];
    }

    const parts = [];
    let currentIndex = 0;
    const placeholderRegex = /__PLACEHOLDER__([^_]+)__[^_]+__/g;
    const foundCount = [];
    let match;

    while ((match = placeholderRegex.exec(text)) !== null) {
      // Add text before placeholder if exists
      if (match.index > currentIndex) {
        parts.push(text.slice(currentIndex, match.index));
      }

      // Add the placeholder element, but only if the placeholder string we found matches
      // the uniqueId we generated earlier for that placeholder.
      if (this._placeholderKeys.get(match[1]) === match[0]) {
        const elIdx = foundCount[match[1]] ?? 0;
        parts.push(this._placeholderElements.get(match[1])[elIdx]);
        foundCount[match[1]] = elIdx + 1;
      }

      currentIndex = match.index + match[0].length;
    }

    // Add remaining text if any
    if (currentIndex < text.length) {
      parts.push(text.slice(currentIndex));
    }

    return parts;
  }

  /**
   * Creates a curried TranslationPlaceholder component for a specific placeholder.
   * This allows the placeholder component to be passed to the template's named block
   * with the placeholder name already bound.
   *
   * @returns {Component} A curried TranslationPlaceholder component with the placeholder name bound
   */
  get curriedPlaceholderComponent() {
    return curryComponent(
      TranslationPlaceholder,
      {
        markAsRendered: this.markAsRendered,
        elements: this._placeholderElements,
      },
      getOwner(this)
    );
  }

  /**
   * Marks a placeholder as having been rendered with content.
   * Called by the TranslationPlaceholder component when it renders.
   *
   * @param {String} name - The name of the placeholder that has been rendered
   */
  @action
  markAsRendered(name) {
    this._renderedPlaceholders.push(name);
  }

  /**
   * Checks for any mismatches between the placeholders expected, and those provided.
   */
  @action
  checkPlaceholders() {
    let missing = [];
    for (const [name, elements] of this._placeholderElements) {
      if (!this._renderedPlaceholders.includes(name)) {
        const value = `[missing ${this._placeholderAppearance.get(
          name
        )} placeholder]`;
        elements.forEach((el) => (el.innerText = value));
        missing.push(value);
      }
    }

    if (missing.length > 0) {
      this.log(
        `Translation error for key '${this.args.key}': ${missing.join(", ")}`,
        I18nMissingInterpolationArgument
      );
    }

    // Confirm that there's a real translation string for the given key.
    const message = I18n.findTranslationWithFallback(this.args.key, {
      ...this._optionsArg,
    });
    if (this._renderedPlaceholders.length === 0 && message) {
      this.log(
        "The <Translation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      );
    }
  }

  /**
   * Throws errors in dev, or logs them to the browser console in production.
   *
   * @param {String} The error message.
   * @param {Class} The type of Error class to throw.
   **/
  log(message, errorClass = Error) {
    if (isProduction()) {
      // eslint-disable-next-line no-console
      console.error(message);
    } else {
      throw new errorClass(message);
    }
  }

  <template>
    {{#each this.textAndPlaceholders as |segment|}}
      {{segment}}
    {{/each}}

    {{yield this.curriedPlaceholderComponent}}
    <span {{didInsert this.checkPlaceholders}} />
  </template>
}
