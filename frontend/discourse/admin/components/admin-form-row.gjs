import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const AdminFormRow = <template>
  <div class="row" ...attributes>
    <div class="form-element label-area">
      {{#if @label}}
        <label
          class={{dConcatClass (if (eq @type "checkbox") "checkbox-label")}}
        >{{i18n @label}}</label>
      {{else}}
        &nbsp;
      {{/if}}
    </div>
    <div class="form-element input-area">
      {{#if @wrapLabel}}
        <label
          class={{dConcatClass (if (eq @type "checkbox") "checkbox-label")}}
        >{{yield}}</label>
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </div>
</template>;

export default AdminFormRow;
