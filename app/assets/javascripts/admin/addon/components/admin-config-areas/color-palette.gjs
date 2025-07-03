import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ColorPaletteEditor, {
  LIGHT,
} from "admin/components/color-palette-editor";

export default class AdminConfigAreasColorPalette extends Component {
  @service toasts;
  @service router;
  @service dialog;

  @tracked editingName = false;
  @tracked editorMode = LIGHT;
  @tracked saving = false;
  @tracked hasChangedName = false;
  @tracked hasChangedUserSelectable = false;
  @tracked hasChangedColors = false;

  saveNameOnly = false;
  fkApi;

  get hasUnsavedChanges() {
    return (
      this.hasChangedName ||
      this.hasChangedUserSelectable ||
      this.hasChangedColors
    );
  }

  @cached
  get data() {
    return {
      name: this.args.colorPalette.name,
      user_selectable: this.args.colorPalette.user_selectable,
      colors: this.args.colorPalette.colors,
    };
  }

  @action
  onRegisterApi(api) {
    this.fkApi = api;
  }

  @action
  toggleEditingName() {
    this.editingName = !this.editingName;
  }

  @action
  onLightColorChange(color, value) {
    color.hex = value;
    this.hasChangedColors = true;
  }

  @action
  onDarkColorChange(color, value) {
    color.dark_hex = value;
    this.hasChangedColors = true;
  }

  @action
  async handleSubmit(data) {
    this.saving = true;
    this.args.colorPalette.name = data.name;

    if (!this.saveNameOnly) {
      this.args.colorPalette.user_selectable = data.user_selectable;
    }

    try {
      await this.args.colorPalette.save({
        saveNameOnly: this.saveNameOnly,
        forceSave: true,
      });
      this.editingName = false;

      this.toasts.success({
        data: {
          message: i18n("saved"),
        },
      });

      this.hasChangedName = false;

      if (!this.saveNameOnly) {
        this.hasChangedUserSelectable = false;

        if (this.hasChangedColors) {
          await this.applyColorChangesIfPossible();
        }
        this.hasChangedColors = false;
      }
    } catch (error) {
      this.toasts.error({
        duration: "short",
        data: {
          message: extractError(error),
        },
      });
    } finally {
      this.saving = false;
    }
  }

  @action
  async triggerNameSave() {
    this.saveNameOnly = true;
    try {
      await this.fkApi.submit();
    } finally {
      this.saveNameOnly = false;
    }
  }

  @action
  onEditorTabSwitch(newMode) {
    this.editorMode = newMode;
  }

  @action
  async copyToClipboard() {
    try {
      await clipboardCopy(this.args.colorPalette.dump());
      this.toasts.success({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.copied_to_clipboard"
          ),
        },
      });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(error);
      this.toasts.error({
        data: {
          message: i18n(
            "admin.config_areas.color_palettes.copy_to_clipboard_error"
          ),
        },
      });
    }
  }

  @action
  async duplicate() {
    const copy = this.args.colorPalette.copy();
    copy.name = i18n("admin.config_areas.color_palettes.copy_of", {
      name: this.args.colorPalette.name,
    });
    await copy.save();
    await this.router.replaceWith("adminConfig.colorPalettes");
    await this.router.refresh();
    await this.router.replaceWith("adminConfig.colorPalettes.show", copy);
    this.toasts.success({
      data: {
        message: i18n("admin.config_areas.color_palettes.copy_created", {
          name: this.args.colorPalette.name,
        }),
      },
    });
  }

  @action
  async delete() {
    return this.dialog.deleteConfirm({
      title: i18n("admin.config_areas.color_palettes.delete_confirm"),
      didConfirm: async () => {
        await this.args.colorPalette.destroy();
        await this.router.replaceWith("adminConfig.colorPalettes");
        await this.router.refresh();
      },
    });
  }

  @action
  handleNameChange(value, { set }) {
    set("name", value);
    this.hasChangedName = true;
  }

  @action
  handleUserSelectableChange(value, { set }) {
    set("user_selectable", value);
    this.hasChangedUserSelectable = true;
  }

  async applyColorChangesIfPossible() {
    const id = this.args.colorPalette.id;

    if (!id) {
      return;
    }

    const tags = document.querySelectorAll(`link[data-scheme-id="${id}"]`);

    if (tags.length === 0) {
      return;
    }

    let darkTag;
    let lightTag;
    for (const tag of tags) {
      if (tag.classList.contains("dark-scheme")) {
        darkTag = tag;
      } else if (tag.classList.contains("light-scheme")) {
        lightTag = tag;
      }
    }

    try {
      const data = await ajax(`/color-scheme-stylesheet/${id}.json`, {
        data: {
          include_dark_scheme: !!darkTag,
        },
      });
      if (data?.new_href && lightTag) {
        lightTag.href = data.new_href;
      }
      if (data?.new_dark_href && darkTag) {
        darkTag.href = data.new_dark_href;
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Failed to apply changes to color palette ${id}`, error);
    }
  }

  <template>
    <Form
      data-palette-id={{@colorPalette.id}}
      @data={{this.data}}
      @onSubmit={{this.handleSubmit}}
      @onRegisterApi={{this.onRegisterApi}}
      as |form transientData|
    >
      <div>
        <div class="admin-config-color-palettes__top-controls">
          {{#if this.editingName}}
            <form.Field
              @name="name"
              @showTitle={{false}}
              @title={{i18n "admin.config_areas.color_palettes.palette_name"}}
              @validation="required"
              @format="full"
              @onSet={{this.handleNameChange}}
              as |field|
            >
              <div class="admin-config-color-palettes__name-control">
                <field.Input />
                <DButton
                  class="btn-primary admin-config-color-palettes__save-name"
                  @icon="check"
                  @action={{this.triggerNameSave}}
                />
                <DButton
                  class="btn-flat"
                  @icon="xmark"
                  @action={{this.toggleEditingName}}
                />
              </div>
            </form.Field>
          {{else}}
            <div class="admin-config-color-palettes__name-control">
              <h2
                class="admin-config-color-palettes__name"
              >{{@colorPalette.name}}</h2>
              <DButton
                class="btn-flat admin-config-color-palettes__edit-name"
                @icon="pencil"
                @action={{this.toggleEditingName}}
              />
            </div>
          {{/if}}
          <div class="admin-config-color-palettes__top-actions">
            <DButton
              class="duplicate-palette"
              @label="admin.config_areas.color_palettes.duplicate"
              @action={{this.duplicate}}
            />
            <DButton
              class="btn-danger delete-palette"
              @label="admin.config_areas.color_palettes.delete"
              @action={{this.delete}}
            />
          </div>
        </div>
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
              <DButton
                class="copy-to-clipboard"
                @label="admin.config_areas.color_palettes.copy_to_clipboard"
                @action={{this.copyToClipboard}}
              />
              <form.Submit
                @isLoading={{this.saving}}
                @label="admin.config_areas.color_palettes.save_changes"
              />
            </div>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </Form>
  </template>
}
