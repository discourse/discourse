import RouteTemplate from "ember-route-template";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div
      class="control-group preferences-navigation-menu-navigation"
      data-setting-name="user-navigation-menu-navigation"
    >
      <legend class="control-label">{{i18n
          "user.experimental_sidebar.navigation_section"
        }}</legend>

      <div class="controls">
        <label>{{i18n
            "user.experimental_sidebar.navigation_section_instruction"
          }}</label>

        <PreferenceCheckbox
          @labelKey="user.experimental_sidebar.link_to_filtered_list_checkbox_description"
          @checked={{@controller.newSidebarLinkToFilteredList}}
          class="pref-link-to-filtered-list"
        />
        <PreferenceCheckbox
          @labelKey="user.experimental_sidebar.show_count_new_items_checkbox_description"
          @checked={{@controller.newSidebarShowCountOfNewItems}}
          class="pref-show-count-new-items"
        />
      </div>
    </div>

    <SaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
