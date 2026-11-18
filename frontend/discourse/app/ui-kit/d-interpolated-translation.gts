import Component from "@glimmer/component";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { getOwner } from "@ember/owner";
import type { WithBoundArgs } from "@glint/template";
import curryComponent from "ember-curry-component";
import { isProduction } from "discourse/lib/environment";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import I18n, { i18n, I18nMissingInterpolationArgument } from "discourse-i18n";

/** The rendering data for a translation, returned by `textAndPlaceholders`. */
interface TranslationPlaceholders {
  appearance: Map<string, string[]>;
  elements: Map<string, HTMLSpanElement[]>;
  keys: Map<string, string>;
  rendered: string[];
  parts: (string | HTMLSpanElement)[];
}

interface PlaceholderSignature {
  Args: {
    /** The name of the placeholder this content should fill. */
    name: string;

    /** A CSS class to apply to the placeholder's wrapper element. */
    class?: string;

    /** Records that the placeholder was rendered. Curried by `DInterpolatedTranslation`. */
    markAsRendered: (name: string) => void;

    /** The elements assigned to each placeholder. Curried by `DInterpolatedTranslation`. */
    elements: Map<string, HTMLSpanElement[]>;
  };

  Blocks: {
    /** The content to render in place of the placeholder. */
    default: [];
  };
}

interface DInterpolatedTranslationSignature {
  Args: {
    /** The i18n translation key to use. */
    key: string;

    /** A hash of options to pass to the i18n function for string interpolation. */
    options?: Record<string, unknown>;
  };

  Blocks: {
    default: [
      /** The component that renders content in place of a placeholder. */
      Placeholder: WithBoundArgs<
        typeof Placeholder,
        "markAsRendered" | "elements"
      >,
    ];
  };
}

/**
 * Provides the ability to interpolate both strings and components into translatable strings.
 * This component allows for complex i18n scenarios where you need to embed interactive
 * components within translated text.
 *
 * If you don't require this specific functionality, use the standard i18n() function.
 *
 * @example
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
 */
export default class DInterpolatedTranslation extends Component<DInterpolatedTranslationSignature> {
  /**
   * Throws errors in dev, or logs them to the browser console in production.
   *
   * @param message - The error message.
   * @param errorClass - The type of Error class to throw.
   **/
  static log(
    message: string,
    errorClass: new (message: string) => Error = Error
  ) {
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
   * @returns The rendering data for the translation.
   */
  get textAndPlaceholders(): TranslationPlaceholders {
    const optionsArg = this.args.options || {};

    // Find all of the placeholders in the string we're looking at.
    const message = I18n.findTranslationWithFallback(this.args.key, {
      ...optionsArg,
      needsPluralization: typeof optionsArg.count === "number",
    });
    const placeholderAppearance = I18n.findPlaceholders(message as string);

    // We only need to keep the placeholders that aren't being handled by those passed in @options.
    Object.keys(optionsArg).forEach((stringPlaceholder) =>
      placeholderAppearance.delete(stringPlaceholder)
    );

    const placeholderKeys = new Map<string, string>();
    const placeholderElements = new Map<string, HTMLSpanElement[]>();

    placeholderAppearance.forEach((placeholderAppearances, placeholderName) => {
      placeholderKeys.set(
        placeholderName,
        `__PLACEHOLDER__${placeholderName}__${dUniqueId()}__`
      );
      placeholderElements.set(
        placeholderName,
        placeholderAppearances.map(() => document.createElement("span"))
      );
    });

    const text: string = i18n(this.args.key, {
      ...Object.fromEntries(placeholderKeys),
      ...optionsArg,
    });

    const parts: (string | HTMLSpanElement)[] = [];
    let currentIndex = 0;
    const placeholderRegex = /__PLACEHOLDER__([^_]+)__[^_]+__/g;
    // How many of each placeholder were found, by name.
    const foundCount: Record<string, number> = {};
    let match: RegExpExecArray | null;

    while ((match = placeholderRegex.exec(text)) !== null) {
      // Add text before placeholder if exists
      if (match.index > currentIndex) {
        parts.push(text.slice(currentIndex, match.index));
      }

      // Add the placeholder element, but only if the placeholder string we found matches
      // the uniqueId we generated earlier for that placeholder.
      if (placeholderKeys.get(match[1]) === match[0]) {
        const elIdx = foundCount[match[1]] ?? 0;
        parts.push(placeholderElements.get(match[1])![elIdx]);
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
   * @param elements - A map of the elements assigned to each placeholder.
   * @param rendered - An array of the placeholders that have been
   *
   * @returns A curried TranslationPlaceholder component
   */
  @action
  curriedPlaceholderComponent(
    elements: Map<string, HTMLSpanElement[]>,
    rendered: string[]
  ) {
    return curryComponent(
      Placeholder,
      {
        markAsRendered: (name: string) => rendered.push(name),
        elements,
      },
      getOwner(this)!
    );
  }

  /**
   * Checks for any mismatches between the placeholders expected, and those provided.
   *
   * @param info - The rendering object returned by textAndPlaceholders().
   */
  @action
  checkPlaceholders(info: TranslationPlaceholders) {
    const missing = [];
    for (const [name, elements] of info.elements) {
      if (!info.rendered.includes(name)) {
        const value = `[missing ${info.appearance.get(name)} placeholder]`;
        elements.forEach((el) => (el.innerText = value));
        missing.push(value);
      }
    }

    if (missing.length > 0) {
      DInterpolatedTranslation.log(
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
      {{DInterpolatedTranslation.log
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
 * @example
 * ```gjs
 * <Placeholder @name="username">
 *   <UserLink @user={{user}}>{{user.username}}</UserLink>
 * </Placeholder>
 * ```
 */
class Placeholder extends Component<PlaceholderSignature> {
  constructor(owner: Owner, args: PlaceholderSignature["Args"]) {
    super(owner, args);
    this.args.markAsRendered(this.args.name);
    const className = this.args.class;
    if (className) {
      this.args.elements
        .get(this.args.name)
        ?.forEach((el) => (el.className = className));
    }
  }

  /**
   * Since `{{get}}` doesn't work with Maps, we need a helper to handle it.
   *
   * @param map - The map we're retrieving from.
   * @param key - The key of the value we're retrieving.
   *
   * @returns The value found, or undefined if there was no matching entry.
   **/
  getFromMap<K, V>(map: Map<K, V>, key: K): V | undefined {
    return map.get(key);
  }

  <template>
    {{#each (this.getFromMap @elements @name) as |element|}}
      {{#in-element element}}
        {{yield}}
      {{/in-element}}
    {{/each}}

    {{#unless (has-block)}}
      {{DInterpolatedTranslation.log
        "The <InterpolatedTranslation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      }}
    {{/unless}}
  </template>
}
