import Component from "@glimmer/component";
import { get } from "@ember/helper";

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
   * Since {{get}} doesn't work with Maps, we need to convert the
   * passed Map of elements to an Object.
   *
   * @type {Object}
   **/
  _elements;

  constructor() {
    super(...arguments);
    this.args.markAsRendered(this.args.name);
    this._elements = Object.fromEntries(this.args.elements);
  }

  <template>
    {{#each (get this._elements @name) as |element|}}
      {{#in-element element}}
        {{yield}}
      {{/in-element}}
    {{/each}}
  </template>
}
