import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class NavigationMenu extends Component {
  @tracked saved = false;

  get saveAttrNames() {
    return applyValueTransformer(
      "preferences-save-attributes",
      ["sidebar_link_to_filtered_list", "sidebar_show_count_of_new_items"],
      { page: "navigation-menu" }
    );
  }

  get formData() {
    return {
      sidebar_link_to_filtered_list: this.args.model.get(
        "user_option.sidebar_link_to_filtered_list"
      ),
      sidebar_show_count_of_new_items: this.args.model.get(
        "user_option.sidebar_show_count_of_new_items"
      ),
    };
  }

  @action
  onSubmit(data) {
    this.args.model.set(
      "user_option.sidebar_link_to_filtered_list",
      data.sidebar_link_to_filtered_list
    );
    this.args.model.set(
      "user_option.sidebar_show_count_of_new_items",
      data.sidebar_show_count_of_new_items
    );

    this.args.model
      .save(this.saveAttrNames)
      .catch(popupAjaxError)
      .finally(() => {
        this.saved = true;
      });
  }

  <template>
    <Form @data={{this.formData}} @onSubmit={{this.onSubmit}} as |form|>
      <form.Section
        @title={{i18n "user.experimental_sidebar.navigation_section"}}
        @subtitle={{i18n
          "user.experimental_sidebar.navigation_section_instruction"
        }}
      >
        <form.Field
          @name="sidebar_link_to_filtered_list"
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
            @checked={{this.formData.sidebar_link_to_filtered_list}}
          />
        </form.Field>
        <form.Field
          @name="sidebar_show_count_of_new_items"
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
            @checked={{this.formData.sidebar_show_count_of_new_items}}
          />
        </form.Field>
      </form.Section>
      <div class="save-controls">
        <form.Submit />
        {{#if this.saved}}
          <span class="saved">{{i18n "saved"}}</span>
        {{/if}}
      </div>
    </Form>
  </template>
}
