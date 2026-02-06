import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";

/**
 * Header component for the sheet, providing left/right action slots and a title.
 *
 * @component DSheetHeader
 * @param {import("./controller").default} sheet - The sheet controller instance providing close action and titleId
 *
 * @slot left - Yields a hash { Back, Cancel, Close } of pre-styled DButton components
 * @slot title - Yields the title content rendered inside the header h2
 * @slot right - Yields a pre-styled DButton component for right-side actions
 */
const Header = <template>
  <div class="d-sheet-header">
    <div class="d-sheet-header__left">
      {{#if (has-block "left")}}
        {{yield
          (hash
            Back=(component
              DButton
              class="btn-transparent btn-primary"
              label="back"
              icon="chevron-left"
            )
            Cancel=(component
              DButton
              class="btn-transparent btn-primary"
              label="cancel"
              action=@sheet.close
            )
            Close=(component
              DButton
              class="btn-transparent btn-primary"
              label="close"
              action=@sheet.close
            )
          )
          to="left"
        }}
      {{/if}}
    </div>

    <h2 class="d-sheet-header__title" id={{@sheet.titleId}}>
      {{#if (has-block "title")}}
        {{yield to="title"}}
      {{/if}}
    </h2>

    <div class="d-sheet-header__right">
      {{#if (has-block "right")}}
        {{yield
          (component DButton class="btn-transparent btn-primary")
          to="right"
        }}
      {{/if}}
    </div>
  </div>
</template>;

export default Header;
