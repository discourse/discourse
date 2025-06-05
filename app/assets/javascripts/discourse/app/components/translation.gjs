import Component from "@glimmer/component";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { modifier } from "ember-modifier";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";

export default class Translation extends Component {
  static Placeholder = <template>
    {{#if @target}}
      {{#in-element @target}}
        {{yield}}
      {{/in-element}}
    {{/if}}
  </template>;

  placeholders = new TrackedObject();

  bindPlaceholder = modifier((element, [name]) => {
    this.placeholders[name] = element;

    return () => {
      delete this.placeholders[name];
    };
  });

  get textAndPlaceholders() {
    const text = i18n(this.args.scope, this.args.options);

    const parts = [];
    let currentIndex = 0;
    const placeholderRegex = /<([^>]+)>/g;
    let match;

    while ((match = placeholderRegex.exec(text)) !== null) {
      // Add text before placeholder if exists
      if (match.index > currentIndex) {
        parts.push({
          type: "text",
          content: text.slice(currentIndex, match.index),
        });
      }

      // Add placeholder
      parts.push({
        type: "placeholder",
        content: match[1], // Capture group without < >
      });

      currentIndex = match.index + match[0].length;
    }

    // Add remaining text if any
    if (currentIndex < text.length) {
      parts.push({
        type: "text",
        content: text.slice(currentIndex),
      });
    }

    return parts;
  }

  <template>
    {{#each this.textAndPlaceholders as |segment|}}
      {{#if (eq segment.type "text")}}
        {{segment.content}}
      {{else}}
        <span {{this.bindPlaceholder segment.content}}></span>
      {{/if}}
      {{yield this.placeholders to="placeholders"}}
    {{/each}}
  </template>
}
