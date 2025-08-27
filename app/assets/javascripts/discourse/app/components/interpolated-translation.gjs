import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import uniqueId from "discourse/helpers/unique-id";
import { isProduction } from "discourse/lib/environment";
import I18n, { i18n, I18nMissingInterpolationArgument } from "discourse-i18n";

/**
 * Provides the ability to interpolate both strings and components into translatable strings.
 * This component allows for complex i18n scenarios where you need to embed interactive
 * components within translated text.
 *
 * If you don't require this specific functionality, use the standard i18n() function.
 *
 * @component InterpolatedTranslation
 *
 * @template Usage example:
 * ```gjs
 * // Translation key: "some.translation.key" = "Welcome, %{username}! The date is %{shortdate}!"
 * <InterpolatedTranslation
 *   @key="some.translation.key"
 *   @options={{hash shortdate=shortDate}}
 *   as |Placeholder|
 * >
 *   <Placeholder @name="username">
 *     <UserLink @user={{user}}>{{user.username}}</UserLink>
 *   </Placeholder>
 * </InterpolatedTranslation>
 * ```
 *
 * @param {String} key - The i18n translation key to use
 * @param {Object} [options] - Hash of options to pass to the i18n function for string interpolation
 */
export default class InterpolatedTranslation extends Component {
  /**
   * Throws errors in dev, or logs them to the browser console in production.
   *
   * @param {String} The error message.
   * @param {Class} The type of Error class to throw.
   **/
  static log(message, errorClass = Error) {
    if (isProduction()) {
      // eslint-disable-next-line no-console
      console.error(message);
    } else {
      throw new errorClass(message);
    }
  }

  /**
   * Processes the translation string and returns all of the rendering data.
   *
   * @returns {Object}
   */
  get textAndPlaceholders() {
    const optionsArg = this.args.options || {};

    // Find all of the placeholders in the string we're looking at.
    const message = I18n.findTranslationWithFallback(this.args.key, {
      ...optionsArg,
    });
    const placeholderAppearance = I18n.findPlaceholders(message);

    // We only need to keep the placeholders that aren't being handled by those passed in @options.
    Object.keys(optionsArg).forEach((stringPlaceholder) =>
      placeholderAppearance.delete(stringPlaceholder)
    );

    const placeholderKeys = new Map();
    const placeholderElements = new Map();

    placeholderAppearance.forEach((placeholderAppearances, placeholderName) => {
      placeholderKeys.set(
        placeholderName,
        `__PLACEHOLDER__${placeholderName}__${uniqueId()}__`
      );
      placeholderElements.set(
        placeholderName,
        placeholderAppearances.map(() => document.createElement("span"))
      );
    });

    const text = i18n(this.args.key, {
      ...Object.fromEntries(placeholderKeys),
      ...optionsArg,
    });

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
      if (placeholderKeys.get(match[1]) === match[0]) {
        const elIdx = foundCount[match[1]] ?? 0;
        parts.push(placeholderElements.get(match[1])[elIdx]);
        foundCount[match[1]] = elIdx + 1;
      }

      currentIndex = match.index + match[0].length;
    }

    // Add remaining text if any
    if (currentIndex < text.length) {
      parts.push(text.slice(currentIndex));
    }

    return {
      appearance: placeholderAppearance,
      elements: placeholderElements,
      keys: placeholderKeys,
      rendered: [],
      parts,
    };
  }

  /**
   * Creates a curried TranslationPlaceholder component for all of the placeholders.
   *
   * @param {Map<String, Array<HTMLElement>>} elements A map of the elements assigned to each placeholder.
   * @param {Array<string>} rendered An array of the placeholders that have been
   *
   * @returns {Component} A curried TranslationPlaceholder component
   */
  @action
  curriedPlaceholderComponent(elements, rendered) {
    return curryComponent(
      Placeholder,
      {
        markAsRendered: (name) => rendered.push(name),
        elements,
      },
      getOwner(this)
    );
  }

  /**
   * Checks for any mismatches between the placeholders expected, and those provided.
   *
   * @param {Object} info The rendering object returned by textAndPlaceholders().
   */
  @action
  checkPlaceholders(info) {
    let missing = [];
    for (const [name, elements] of info.elements) {
      if (!info.rendered.includes(name)) {
        const value = `[missing ${info.appearance.get(name)} placeholder]`;
        elements.forEach((el) => (el.innerText = value));
        missing.push(value);
      }
    }

    if (missing.length > 0) {
      InterpolatedTranslation.log(
        `Translation error for key '${this.args.key}': ${missing.join(", ")}`,
        I18nMissingInterpolationArgument
      );
    }
  }

  <template>
    {{#let this.textAndPlaceholders as |info|}}
      {{#each info.parts as |part|}}
        {{part}}
      {{/each}}

      {{yield (this.curriedPlaceholderComponent info.elements info.rendered)}}
      {{this.checkPlaceholders info}}
    {{/let}}

    {{#unless (has-block)}}
      {{InterpolatedTranslation.log
        "The <InterpolatedTranslation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      }}
    {{/unless}}
  </template>
}

/**
 * Internally used by the Translation component to render placeholder
 * content. This component conditionally renders its content only when the
 * placeholder name matches the expected placeholder key.
 *
 * This component is only used through the Translation component's yielded
 * Placeholder component, rather than directly.
 *
 * @component Placeholder
 *
 * @template Usage example:
 * ```gjs
 * <Placeholder @name="username">
 *   <UserLink @user={{user}}>{{user.username}}</UserLink>
 * </Placeholder>
 * ```
 *
 * @param {String} name - The name of the placeholder this content should fill
 */
class Placeholder extends Component {
  constructor() {
    super(...arguments);
    this.args.markAsRendered(this.args.name);
  }

  /**
   * Since {{get}} doesn't work with Maps, we need a helper to handle it.
   *
   * @param {Map<any,any>} map The map we're retrieving from.
   * @param {any} key The key of the value we're retrieving.
   *
   * @returns {any|undefined} The value found, or undefined if there was no matching entry.
   **/
  getFromMap(map, key) {
    return map.get(key);
  }

  <template>
    {{#each (this.getFromMap @elements @name) as |element|}}
      {{#in-element element}}
        {{yield}}
      {{/in-element}}
    {{/each}}

    {{#unless (has-block)}}
      {{InterpolatedTranslation.log
        "The <InterpolatedTranslation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      }}
    {{/unless}}
  </template>
}
