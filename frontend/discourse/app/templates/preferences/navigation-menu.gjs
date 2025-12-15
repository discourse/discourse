import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class NavigationMenu extends Component {
  get saveAttrNames() {
    return applyValueTransformer(
      "preferences-save-attributes",
      ["sidebar_link_to_filtered_list", "sidebar_show_count_of_new_items"],
      { page: "navigation-menu" }
    );
  }

  get formData() {
    return {
      newSidebarLinkToFilteredList: this.args.model.get(
        "user_option.sidebar_link_to_filtered_list"
      ),
      newSidebarShowCountOfNewItems: this.args.model.get(
        "user_option.sidebar_show_count_of_new_items"
      ),
    };
  }

  @action
  onSubmit(data) {
    this.args.model
      .save(this.saveAttrNames)
      .then(() => {
        this.saved = true;
      })
      .catch((error) => {
        this.args.model.set(
          "user_option.sidebar_link_to_filtered_list",
          data.newSidebarLinkToFilteredList
        );
        this.args.model.set(
          "user_option.sidebar_show_count_of_new_items",
          data.newSidebarShowCountOfNewItems
        );

        popupAjaxError(error);
      });
  }

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

    <Form @data={{this.formData}} @onSubmit={{this.onSubmit}} as |form|>
      <form.Section
        @title={{i18n "user.experimental_sidebar.navigation_section"}}
        @subtitle={{i18n
          "user.experimental_sidebar.navigation_section_instruction"
        }}
      >
        <form.Field
          @name="newSidebarLinkToFilteredList"
          @title={{i18n
            "user.experimental_sidebar.link_to_filtered_list_checkbox_description"
          }}
          @label={{i18n
            "user.experimental_sidebar.link_to_filtered_list_checkbox_description"
          }}
          @format="large"
          as |field|
        >
          <field.Checkbox
            @checked={{this.formData.newSidebarLinkToFilteredList}}
          />
        </form.Field>
        <form.Field
          @name="newSidebarShowCountOfNewItems"
          @title={{i18n
            "user.experimental_sidebar.show_count_new_items_checkbox_description"
          }}
          @label={{i18n
            "user.experimental_sidebar.show_count_new_items_checkbox_description"
          }}
          @format="large"
          as |field|
        >
          <field.Checkbox
            @checked={{this.formData.newSidebarShowCountOfNewItems}}
          />
        </form.Field>
      </form.Section>
      <form.Submit />
    </Form>
  </template>
}
