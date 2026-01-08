import Component from "@glimmer/component";

/**
 * Scroll-trap stabilizer for special layouts.
 * Provides stable positioning for content within the scroll-trap.
 *
 * @component DSheetSpecialWrapperContent
 */
export default class DSheetSpecialWrapperContent extends Component {
  <template>
    <div data-d-sheet="scroll-trap-stabilizer" ...attributes>
      {{yield}}
    </div>
  </template>
}
