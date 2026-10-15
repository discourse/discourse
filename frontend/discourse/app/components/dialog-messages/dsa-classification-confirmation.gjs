import { i18n } from "discourse-i18n";

const DsaClassificationConfirmation = <template>
  <p>{{i18n "dsa_statements.confirm_message"}}</p>
  <dl class="dsa-classification-confirmation">
    <dt class="dsa-classification-confirmation__label">{{i18n
        "dsa_statements.rule"
      }}</dt>
    <dd class="dsa-classification-confirmation__value">{{@model.rule}}</dd>
    <dt class="dsa-classification-confirmation__label">{{i18n
        "dsa_statements.category"
      }}</dt>
    <dd class="dsa-classification-confirmation__value">{{@model.category}}</dd>
  </dl>
</template>;

export default DsaClassificationConfirmation;
