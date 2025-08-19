import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import BackButton from "discourse/components/back-button";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";

export default RouteTemplate(
  <template>
    <div
      class="admin-detail discourse-automation-new discourse-automation-form"
    >
      <BackButton
        @label="discourse_automation.back"
        @route="adminPlugins.show.automation.index"
        class="discourse-automation-back"
      />
      <AdminConfigAreaCard @heading="discourse_automation.select_script">
        <:content>
          <input
            type="text"
            placeholder={{i18n "discourse_automation.filter_placeholder"}}
            {{on "input" @controller.updateFilterText}}
            class="admin-section-landing__header-filter"
          />

          <div class="admin-section-landing__wrapper">
            {{#each @controller.scriptableContent as |script|}}
              <AdminSectionLandingItem
                {{on "click" (fn @controller.selectScriptToEdit script)}}
                @titleLabelTranslated={{script.name}}
                @descriptionLabelTranslated={{script.description}}
              />
            {{/each}}
          </div>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
);
