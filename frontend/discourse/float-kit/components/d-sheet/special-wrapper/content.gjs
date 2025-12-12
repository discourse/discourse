import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

/**
 * Scroll-trap stabilizer for special layouts.
 * Provides stable positioning for content within the scroll-trap.
 *
 * @component DSheetSpecialWrapperContent
 */
export default class DSheetSpecialWrapperContent extends Component {
  <template>
    <div
      class={{concatClass "Sheet-specialWrapperContent" @class}}
      data-d-sheet={{concatClass
        "scroll-trap-stabilizer"
        "special-wrapper-content"
      }}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
