import Component from "@glimmer/component";

/**
 * A component that iterates over an array and yields each item,
 * inserting a separator between items (but not before the first or after the last).
 *
 * Usage:
 * <SeparatedList
 *   @items={{someArray}}
 *   @separator=", "
 *   as |item|
 * >
 *   <a href={{(concat "/item/" item)}}>{{item}}</a>
 * </SeparatedList>
 */
export default class SeparatedList extends Component {
  get items() {
    return this.args.items || [];
  }

  get separator() {
    return this.args.separator ?? ", ";
  }

  <template>
    <span ...attributes>
      {{#each this.items as |item index|}}
        {{#if index}}{{this.separator}}{{/if}}{{yield item index}}
      {{/each}}
    </span>
  </template>
}
