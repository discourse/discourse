import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ColorPaletteEditor from "admin/components/color-palette-editor";

export default class AdminConfigAreasColorPalette extends Component {
  @tracked editingName = false;

  @cached
  get data() {
    return {
      name: this.args.colorPalette.name,
      editingName: this.editingName,
      user_selectable: this.args.colorPalette.user_selectable,
      colors: this.args.colorPalette.colors.map((color) => {
        return {
          name: color.name,
          hex: color.hex,
          dark_hex: color.dark_hex,
        };
      }),
    };
  }

  get colors() {
    return this.args.colorPalette.colors.map((color) => {
      return {
        name: color.name,
        hex: color.hex,
        dark_hex: color.dark_hex,
        description: i18n(`admin.customize.colors.${color.name}.description`),
        displayName: i18n(`admin.customize.colors.${color.name}.name`),
      };
    });
  }

  @action
  toggleEditingName() {
    this.editingName = !this.editingName;
  }

  @action
  onLightColorChange(fieldSet, transientData, name, value) {
    fieldSet(
      transientData.colors.map((color) => {
        if (color.name === name) {
          return {
            name,
            hex: value,
            dark_hex: color.dark_hex,
          };
        } else {
          return color;
        }
      })
    );
  }

  @action
  onDarkColorChange(fieldSet, transientData, name, value) {
    fieldSet(
      transientData.colors.map((color) => {
        if (color.name === name) {
          return {
            name,
            hex: color.hex,
            dark_hex: value,
          };
        } else {
          return color;
        }
      })
    );
  }

  @action
  async handleSubmit(data) {
    await this.args.colorPalette.performSave(data);
    this.args.colorPalette.name = data.name;
    this.editingName = false;
  }

  <template>
    <Form
      @data={{this.data}}
      @onSubmit={{this.handleSubmit}}
      as |form transientData|
    >
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          <div class="admin-config-color-palettes__top-controls">
            <form.Field
              @name="name"
              @showTitle={{false}}
              @title={{i18n "admin.config_areas.color_palettes.palette_name"}}
              @validation="required"
              as |field|
            >
              {{#if transientData.editingName}}
                <div class="admin-config-color-palettes__name-control">
                  <field.Input />
                  <DButton
                    class="btn-flat"
                    @icon="xmark"
                    @action={{this.toggleEditingName}}
                  />
                </div>
              {{else}}
                <field.Custom>
                  <div class="admin-config-color-palettes__name-control">
                    <h2>{{@colorPalette.name}}</h2>
                    <DButton
                      class="btn-flat"
                      @icon="pencil"
                      @action={{this.toggleEditingName}}
                    />
                  </div>
                </field.Custom>
              {{/if}}
            </form.Field>
            <DButton @label="admin.customize.copy" />
          </div>
          <form.Alert class="fonts-and-logos-hint">
            <div class="admin-config-color-palettes__fonts-and-logos-hint">
              <span>{{i18n
                  "admin.config_areas.color_palettes.fonts_and_logos_hint"
                }}</span>
              <a>{{i18n "admin.config_areas.color_palettes.go_to_branding"}}</a>
            </div>
          </form.Alert>
          <AdminConfigAreaCard
            @heading="admin.config_areas.color_palettes.color_options.title"
          >
            <:content>
              <form.Field
                @name="user_selectable"
                @title={{i18n
                  "admin.config_areas.color_palettes.color_options.toggle"
                }}
                @showTitle={{false}}
                @description={{i18n
                  "admin.config_areas.color_palettes.color_options.toggle_description"
                }}
                @format="full"
                as |field|
              >
                <field.Toggle />
              </form.Field>
            </:content>
          </AdminConfigAreaCard>
          <AdminConfigAreaCard
            @heading="admin.config_areas.color_palettes.colors.title"
          >
            <:content>
              <form.Field
                @name="colors"
                @title={{i18n "admin.config_areas.color_palettes.colors.title"}}
                @showTitle={{false}}
                @format="full"
                as |field|
              >
                <field.Custom>
                  <ColorPaletteEditor
                    @onLightColorChange={{fn
                      this.onLightColorChange
                      field.set
                      transientData
                    }}
                    @onDarkColorChange={{fn
                      this.onDarkColorChange
                      field.set
                      transientData
                    }}
                    @colors={{this.colors}}
                  />
                </field.Custom>
              </form.Field>
            </:content>
          </AdminConfigAreaCard>
          <AdminConfigAreaCard>
            <:content>
              <div class="admin-config-color-palettes__save-card">
                {{#if false}}
                  <span class="admin-config-color-palettes__unsaved-changes">
                    {{i18n "admin.config_areas.color_palettes.unsaved_changes"}}
                  </span>
                {{/if}}
                <form.Submit
                  @label="admin.config_areas.color_palettes.save_changes"
                />
              </div>
            </:content>
          </AdminConfigAreaCard>
        </div>
      </div>
    </Form>
  </template>
}
