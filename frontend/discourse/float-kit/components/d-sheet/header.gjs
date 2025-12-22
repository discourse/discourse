import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";

/**
 * Header component for the sheet.
 *
 * @component DSheetHeader
 * @param {Object} sheet - The sheet controller instance
 *
 * @slot left - Yields a hash { Back, Cancel } of pre-styled buttons
 * @slot title - Yields the title content (or use default yield)
 * @slot right - Yields a pre-styled action button
 */
export default class Header extends Component {
  <template>
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
            (component
              DButton class="btn-transparent btn-primary" action=@action
            )
            to="right"
          }}
        {{/if}}
      </div>
    </div>
  </template>
}
