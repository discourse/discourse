import { fn, hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DButton from "discourse/ui-kit/d-button";

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
              action=(fn @sheet.requestDismiss)
            )
            Close=(component
              DButton
              class="btn-transparent btn-primary"
              label="close"
              action=(fn @sheet.requestDismiss)
            )
          )
          to="left"
        }}
      {{/if}}
    </div>

    {{#if (has-block "title")}}
      <h2
        class="d-sheet-header__title"
        id={{@sheet.titleId}}
        {{didInsert @sheet.registerTitle}}
        {{willDestroy @sheet.unregisterTitle}}
      >
        {{yield to="title"}}
      </h2>
    {{else}}
      <div class="d-sheet-header__title"></div>
    {{/if}}

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
