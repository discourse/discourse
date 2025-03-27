import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classify, decamelize, underscore } from "@ember/string";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import UpdateDefaultTextSize from "discourse/components/modal/update-default-text-size";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import eq from "truth-helpers/helpers/eq";

const FONTS = [
  "Arial",
  "Helvetica",
  "Inter",
  "Lato",
  "Lora",
  "Merriweather",
  "Montserrat",
  "Mukta",
  "NotoSans",
];
const MORE_FONTS = [
  "NotoSansJP",
  "Nunito",
  "OpenSans",
  "Oswald",
  "Oxanium",
  "PT Sans",
  "PlayfairDisplay",
  "Poppins",
  "Raleway",
  "Roboto",
  "RobotoCondensed",
  "RobotoMono",
  "RobotoSlab",
  "SourceSansPro",
  "System",
  "Ubuntu",
];

const TEXT_SIZES = ["smaller", "normal", "larger", "largest"];

export default class AdminBrandingFontsForm extends Component {
  @service siteSettings;
  @service toasts;
  @service modal;

  @tracked moreBaseFonts = MORE_FONTS.includes(
    classify(this.siteSettings.base_font)
  );
  @tracked moreHeadingFonts = MORE_FONTS.includes(
    classify(this.siteSettings.heading_font)
  );
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
  toggleMoreBaseFonts() {
    this.moreBaseFonts = !this.moreBaseFonts;
  }

  @action
  toggleMoreHeadingFonts() {
    this.moreHeadingFonts = !this.moreHeadingFonts;
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
      await ajax("/admin/config/branding/fonts.json", {
        type: "PUT",
        data: {
          base_font: data.base_font,
          heading_font: data.heading_font,
          default_text_size: data.default_text_size,
          update_existing_users: this.updateExistingUsers,
        },
      });
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n("admin.config.branding.fonts.form.saved"),
        },
      });
      window.location.reload();
    } catch (err) {
      this.toasts.error({
        duration: 3000,
        data: {
          message: err.jqXHR.responseJSON.errors[0],
        },
      });
    }
  }

  @cached
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
        @title={{i18n "admin.config.branding.fonts.form.base_font.title"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.Custom>
          {{#each FONTS as |font|}}
            <DButton
              @action={{fn this.setButtonValue field.set font}}
              class={{concatClass
                "admin-fonts-form__button-option font btn-flat"
                (decamelize (underscore font))
                (if
                  (eq transientData.base_font (decamelize (underscore font)))
                  "active"
                )
              }}
            >{{font}}</DButton>
          {{/each}}
          {{#if this.moreBaseFonts}}
            {{#each MORE_FONTS as |font|}}
              <DButton
                @action={{fn this.setButtonValue field.set font}}
                class={{concatClass
                  "admin-fonts-form__button-option font btn-flat"
                  (decamelize (underscore font))
                  (if
                    (eq transientData.base_font (decamelize (underscore font)))
                    "active"
                  )
                }}
              >{{font}}</DButton>
            {{/each}}
          {{/if}}
          <DButton
            @action={{this.toggleMoreBaseFonts}}
            class="admin-fonts-form__more font"
          >
            {{#if this.moreBaseFonts}}
              {{i18n "admin.config.branding.fonts.form.less_fonts"}}
            {{else}}
              {{i18n "admin.config.branding.fonts.form.more_fonts"}}
            {{/if}}
          </DButton>
        </field.Custom>
      </form.Field>
      <form.Field
        @name="heading_font"
        @title={{i18n "admin.config.branding.fonts.form.heading_font.title"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.Custom>
          {{#each FONTS as |font|}}
            <DButton
              @action={{fn this.setButtonValue field.set font}}
              class={{concatClass
                "admin-fonts-form__button-option font btn-flat"
                (decamelize (underscore font))
                (if
                  (eq transientData.heading_font (decamelize (underscore font)))
                  "active"
                )
              }}
            >{{font}}</DButton>
          {{/each}}
          {{#if this.moreHeadingFonts}}
            {{#each MORE_FONTS as |font|}}
              <DButton
                @action={{fn this.setButtonValue field.set font}}
                class={{concatClass
                  "admin-fonts-form__button-option font btn-flat"
                  (decamelize (underscore font))
                  (if
                    (eq
                      transientData.heading_font (decamelize (underscore font))
                    )
                    "active"
                  )
                }}
              >{{font}}</DButton>

            {{/each}}
          {{/if}}
          <DButton
            @action={{this.toggleMoreHeadingFonts}}
            class="admin-fonts-form__more font"
          >
            {{#if this.moreHeadingFonts}}
              {{i18n "admin.config.branding.fonts.form.less_fonts"}}
            {{else}}
              {{i18n "admin.config.branding.fonts.form.more_fonts"}}
            {{/if}}
          </DButton>
        </field.Custom>
      </form.Field>
      <form.Field
        @name="default_text_size"
        @title={{i18n
          "admin.config.branding.fonts.form.default_text_size.title"
        }}
        @description={{i18n
          "admin.config.branding.fonts.form.default_text_size.description"
        }}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.Custom>
          {{#each TEXT_SIZES as |textSize|}}
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
