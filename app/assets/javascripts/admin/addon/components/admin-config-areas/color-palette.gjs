import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ColorPaletteEditor, {
  LIGHT,
} from "admin/components/color-palette-editor";

export default class AdminConfigAreasColorPalette extends Component {
  @service toasts;
  @service router;

  @tracked editingName = false;
  @tracked editorMode = LIGHT;
  @tracked hasUnsavedChanges = false;

  @cached
  get data() {
    return {
      name: this.args.colorPalette.name,
      user_selectable: this.args.colorPalette.user_selectable,
      colors: this.args.colorPalette.colors,
      editingName: this.editingName,
    };
  }

  @action
  toggleEditingName() {
    this.editingName = !this.editingName;
  }

  @action
  onLightColorChange(name, value) {
    const color = this.data.colors.find((c) => c.name === name);
    color.hex = value;
    this.hasUnsavedChanges = true;
  }

  @action
  onDarkColorChange(name, value) {
    const color = this.data.colors.find((c) => c.name === name);
    color.dark_hex = value;
    this.hasUnsavedChanges = true;
  }

  @action
  async handleSubmit(data) {
    this.args.colorPalette.name = data.name;
    this.args.colorPalette.user_selectable = data.user_selectable;

    try {
      await this.args.colorPalette.save();
      this.editingName = false;
      this.hasUnsavedChanges = false;
      this.toasts.success({
        data: {
          message: i18n("saved"),
        },
      });
    } catch (error) {
      this.toasts.error({
        duration: 3000,
        data: {
          message: extractError(error),
        },
      });
    }
  }

  @action
  onEditorTabSwitch(newMode) {
    this.editorMode = newMode;
  }

  @action
  async duplicate() {
    const copy = this.args.colorPalette.copy();
    copy.name = i18n("admin.config_areas.color_palettes.copy_of", {
      name: this.args.colorPalette.name,
    });
    await copy.save();
    this.router.replaceWith("adminConfig.color-palettes-show", copy);
    this.toasts.success({
      data: {
        message: i18n("admin.config_areas.color_palettes.copy_created", {
          name: this.args.colorPalette.name,
        }),
      },
    });
  }

  @action
  handleNameChange(value, { set }) {
    set("name", value);
    this.hasUnsavedChanges = true;
  }

  @action
  handleUserSelectableChange(value, { set }) {
    set("user_selectable", value);
    this.hasUnsavedChanges = true;
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
              @format="full"
              @onSet={{this.handleNameChange}}
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
            <DButton
              class="duplicate-palette"
              @label="admin.customize.copy"
              @action={{this.duplicate}}
            />
          </div>
          <form.Alert class="fonts-and-logos-hint">
            <div class="admin-config-color-palettes__fonts-and-logos-hint">
              <span>{{i18n
                  "admin.config_areas.color_palettes.fonts_and_logos_hint"
                }}</span>
              <LinkTo @route="adminConfig.branding">{{i18n
                  "admin.config_areas.color_palettes.go_to_branding"
                }}</LinkTo>
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
                @onSet={{this.handleUserSelectableChange}}
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
                    @initialMode={{this.editorMode}}
                    @colors={{transientData.colors}}
                    @onLightColorChange={{this.onLightColorChange}}
                    @onDarkColorChange={{this.onDarkColorChange}}
                    @onTabSwitch={{this.onEditorTabSwitch}}
                  />
                </field.Custom>
              </form.Field>
            </:content>
          </AdminConfigAreaCard>
          <AdminConfigAreaCard>
            <:content>
              <div class="admin-config-color-palettes__save-card">
                {{#if this.hasUnsavedChanges}}
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
