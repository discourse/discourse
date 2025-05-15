import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { decamelize, underscore } from "@ember/string";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import UpdateDefaultTextSize from "discourse/components/modal/update-default-text-size";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AdminFontChooser from "admin/components/admin-font-chooser";
import {
  DEFAULT_TEXT_SIZES,
  MAIN_FONTS,
  MORE_FONTS,
} from "admin/lib/constants";

const ALL_FONTS = [...MAIN_FONTS, ...MORE_FONTS];

export default class AdminFontsForm extends Component {
  @service siteSettings;
  @service siteSettingChangeTracker;
  @service toasts;
  @service modal;
  @service router;

  updateExistingUsers = null;

  @bind
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  }

  @action
  setButtonValue(fieldSet, value) {
    fieldSet(decamelize(underscore(value)));
  }

  @action
  async update(data) {
    if (this.siteSettings.default_text_size === data.default_text_size) {
      await this.#save(data);
      return;
    }

    const result = await ajax(
      `/admin/site_settings/default_text_size/user_count.json`,
      {
        type: "PUT",
        data: {
          default_text_size: data.default_text_size,
        },
      }
    );

    const count = result.user_count;
    if (count > 0) {
      await this.modal.show(UpdateDefaultTextSize, {
        model: {
          setUpdateExistingUsers: this.setUpdateExistingUsers,
          count,
        },
      });
      await this.#save(data);
    } else {
      await this.#save(data);
    }
  }

  @action
  async #save(data) {
    try {
      await ajax("/admin/config/fonts.json", {
        type: "PUT",
        data: {
          base_font: data.base_font,
          heading_font: data.heading_font,
          default_text_size: data.default_text_size,
          update_existing_users: this.updateExistingUsers,
        },
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.config.fonts.form.saved"),
        },
      });
      this.siteSettingChangeTracker.refreshPage({
        base_font: ALL_FONTS.find((font) => font.key === data.base_font).name,
        heading_font: ALL_FONTS.find((font) => font.key === data.heading_font)
          .name,
        default_text_size: data.default_text_size,
      });
    } catch (err) {
      this.toasts.error({
        duration: "short",
        data: {
          message: err.jqXHR.responseJSON.errors[0],
        },
      });
    }
  }

  get formData() {
    return {
      base_font: this.siteSettings.base_font,
      heading_font: this.siteSettings.heading_font,
      default_text_size: this.siteSettings.default_text_size,
    };
  }

  <template>
    <Form
      @onSubmit={{this.update}}
      @data={{this.formData}}
      class="admin-fonts-form"
      as |form transientData|
    >
      <form.Field
        @name="base_font"
        @title={{i18n "admin.config.fonts.form.base_font.title"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <AdminFontChooser
          @field={{field}}
          @selectedFont={{transientData.base_font}}
        />
      </form.Field>
      <form.Field
        @name="heading_font"
        @title={{i18n "admin.config.fonts.form.heading_font.title"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <AdminFontChooser
          @field={{field}}
          @selectedFont={{transientData.heading_font}}
        />
      </form.Field>
      <form.Field
        @name="default_text_size"
        @title={{i18n "admin.config.fonts.form.default_text_size.title"}}
        @description={{i18n
          "admin.config.fonts.form.default_text_size.description"
        }}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.Custom>
          {{#each DEFAULT_TEXT_SIZES as |textSize|}}
            <DButton
              @action={{fn this.setButtonValue field.set textSize}}
              class={{concatClass
                "admin-fonts-form__button-option text-size btn-flat"
                textSize
                (if (eq transientData.default_text_size textSize) "active")
              }}
            >{{textSize}}</DButton>
          {{/each}}
        </field.Custom>
      </form.Field>
      <form.Submit />
    </Form>
  </template>
}
