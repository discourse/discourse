import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { animatedEmojiUrlFor, emojiUrlFor } from "discourse/lib/text";

// Shared so every instance, current and future, stops requesting an emoji
// that has no animation after the first miss.
const missingAnimations = trackedSet<string>();

interface DAnimatedEmojiSignature {
  Args: {
    /** The emoji's name, optionally with a skin tone (`clap`, `clap:t3`). */
    code: string;
    /** Translated tooltip and alternative text. Defaults to the emoji's name. */
    title?: string;
  };
  Element: HTMLImageElement;
}

/**
 * Renders an emoji animated, when an animation exists for it and the user
 * hasn't asked for reduced motion; otherwise renders the site's static image,
 * as do custom emojis. Renders nothing when emojis are disabled or the name is
 * unknown.
 */
export default class DAnimatedEmoji extends Component<DAnimatedEmojiSignature> {
  get code() {
    return this.args.code.toLowerCase();
  }

  get staticUrl(): string | undefined {
    return emojiUrlFor(this.code);
  }

  get animatedUrl(): string | undefined {
    if (!missingAnimations.has(this.code)) {
      return animatedEmojiUrlFor(this.code);
    }
  }

  get title() {
    return this.args.title ?? this.code;
  }

  @action
  handleError(event: Event) {
    const image = event.target as HTMLImageElement;
    const animatedUrl = this.animatedUrl;

    // Dropping the source makes the browser pick the static image instead.
    if (animatedUrl && image.currentSrc.endsWith(animatedUrl)) {
      missingAnimations.add(this.code);
    }
  }

  <template>
    {{#if this.staticUrl}}
      <picture class="d-animated-emoji">
        {{#if this.animatedUrl}}
          <source
            media="(prefers-reduced-motion: no-preference)"
            srcset={{this.animatedUrl}}
            type="image/avif"
          />
        {{/if}}
        <img
          alt={{this.title}}
          class="emoji d-animated-emoji__image"
          src={{this.staticUrl}}
          title={{this.title}}
          ...attributes
          {{on "error" this.handleError}}
        />
      </picture>
    {{/if}}
  </template>
}
