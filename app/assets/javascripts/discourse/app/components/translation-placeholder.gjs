import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq } from "truth-helpers";

/**
 * Internally used by the Translation component to render placeholder
 * content. This component conditionally renders its content only when the
 * placeholder name matches the expected placeholder key.
 *
 * This component is only used through the Translation component's yielded
 * Placeholder component, rather than directly.
 *
 * @component TranslationPlaceholder
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
export default class TranslationPlaceholder extends Component {
  /**
   * Calls the parent component's markAsRendered function, to track that this
   * placeholder has been rendered.
   */
  @action
  markAsRendered() {
    this.args.markAsRendered(this.args.placeholder);
  }

  <template>
    {{#if (eq @placeholder @name)}}
      {{yield}}
      <span {{didInsert this.markAsRendered}} />
    {{/if}}
  </template>
}
