import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import LovelaceChecklist from "discourse/plugins/lovelace/discourse/components/lovelace-checklist";

export default <template>
  <DPageSubheader
    @descriptionLabel={{i18n "lovelace.description"}}
    @titleLabel={{i18n "lovelace.configure"}}
  />
  <div class="admin-config-page__main-area">
    <LovelaceChecklist @editing={{true}} @model={{@model}} />
  </div>
</template>
