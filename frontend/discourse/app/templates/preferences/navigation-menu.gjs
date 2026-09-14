import PreferenceCheckbox from "discourse/components/preference-checkbox";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
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
        class="pref-link-to-filtered-list"
        @checked={{@controller.newSidebarLinkToFilteredList}}
        @labelKey="user.experimental_sidebar.link_to_filtered_list_checkbox_description"
      />
      <PreferenceCheckbox
        class="pref-show-count-new-items"
        @checked={{@controller.newSidebarShowCountOfNewItems}}
        @labelKey="user.experimental_sidebar.show_count_new_items_checkbox_description"
      />
    </div>
  </div>

  <DSaveControls
    @action={{@controller.save}}
    @model={{@controller.model}}
    @saved={{@controller.saved}}
  />
</template>
