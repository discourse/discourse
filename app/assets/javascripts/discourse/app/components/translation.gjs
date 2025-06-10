import Component from "@glimmer/component";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";
import { i18n } from "discourse-i18n";

/**
 * Provides the ability to interpolate both strings and components into translatable strings. For example:
 *
 * // "some.translation.key" = "Welcome, %{username}! The date is %{shortdate}!"
 * <Translation
 *   @scope="some.translation.key"
 *   @placeholders={{array "username"}}
 *   @options={{hash shortdate=shortDate}}
 * >
 *   <:placeholders as |placeholder|>
 *     <placeholder @name="username">
 *       <UserLink @user={{user}}>{{user.username}}</UserLink>
 *     </placeholder>
 *   </:placeholders>
 * </Translation>
 **/
export default class Translation extends Component {
  placeholderKeys = new TrackedObject();
  placeholderElements = {};

  get textAndPlaceholders() {
    const optionsArg = this.args.options || {};
    const placeholdersArg = this.args.placeholders || [];

    placeholdersArg.forEach((placeholderKey) => {
      this.placeholderKeys[placeholderKey] =
        `__PLACEHOLDER__${placeholderKey}__${uniqueId()}__`;
      this.placeholderElements[placeholderKey] = document.createElement("span");
    });

    const text = i18n(this.args.scope, {
      ...this.placeholderKeys,
      ...optionsArg,
    });

    const parts = [];
    let currentIndex = 0;
    const placeholderRegex = /__PLACEHOLDER__([^_]+)__[^_]+__/g;
    let match;

    while ((match = placeholderRegex.exec(text)) !== null) {
      // Add text before placeholder if exists
      if (match.index > currentIndex) {
        parts.push(text.slice(currentIndex, match.index));
      }

      // Add the placeholder element, but only if the placeholder string we found matches
      // the uniqueId we generated earlier for that placeholder.
      if (this.placeholderKeys[match[1]] === match[0]) {
        parts.push(this.placeholderElements[match[1]]);
      }

      currentIndex = match.index + match[0].length;
    }

    // Add remaining text if any
    if (currentIndex < text.length) {
      parts.push(text.slice(currentIndex));
    }

    return parts;
  }

  placeholderElement(placeholder) {
    return <template>
      {{#if (eq placeholder @name)}}
        {{yield}}
      {{/if}}
    </template>;
  }

  <template>
    {{#each this.textAndPlaceholders as |segment|}}
      {{segment}}
    {{/each}}

    {{#each-in this.placeholderElements as |placeholderKey placeholderElement|}}
      {{#in-element placeholderElement}}
        {{yield (this.placeholderElement placeholderKey) to="placeholders"}}
      {{/in-element}}
    {{/each-in}}
  </template>
}
