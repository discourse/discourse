import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import QuoteSelectionMixin from "discourse/mixins/quote-selection";
import { translateModKey } from "discourse/lib/utilities";

export default Component.extend(QuoteSelectionMixin, {
  init() {
    this._super(...arguments);

    this._saveEditButtonTitle = I18n.t("composer.title", {
      modifier: translateModKey("Meta+"),
    });
  },

  @discourseComputed("siteSettings.enable_fast_edit")
  canFastEdit(enableFastEdit) {
    return enableFastEdit;
  },
});
