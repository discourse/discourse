import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import AdvancedModeToggle from "discourse/components/advanced-mode-toggle";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DIconGridPickerContent from "discourse/ui-kit/d-icon-grid-picker/content";
import DModal from "discourse/ui-kit/d-modal";
import DNameStyleInput from "discourse/ui-kit/d-name-style-input";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";
import {
  ASSIGNED_OPTIONS,
  assignedMode,
  assignedUserValue,
  COLUMN_SORT_OPTIONS,
  PRESET_COLUMN_COLORS,
  STATUS_OPTIONS,
  tagToArray,
} from "../../lib/boards-column-helpers.js";

function iconColorStyle(color) {
  if (isValidHex(color)) {
    return trustHTML(`--icon-color: #${normalizeHex(color)}`);
  }
}

function styleLabel(icon) {
  return icon
    ? i18n("boards.manage.columns.choose_style_with_icon", {
        name: icon.replace(/^fa[brs]-/, "").replace(/[-_]/g, " "),
      })
    : i18n("boards.manage.columns.choose_style");
}

export default class BoardsColumnSettings extends Component {
  @tracked showAdvanced = false;

  @cached
  get formData() {
    const column = this.args.model.column;
    return {
      title: column?.title || "",
      icon: column?.icon || null,
      color: column?.color || null,
      default_sort: column?.default_sort || "priority",
      tag_name: column?.tag_name || "",
      move_to_category_id: column?.move_to_category_id || null,
      move_to_assigned: column?.move_to_assigned || "",
      move_to_status: column?.move_to_status || "",
    };
  }

  // NOTE: We are aware this is not ideal because a board
  // can have multiple categories, but we only support one
  // for now because server-side the tag search is limited
  // to one category at a time.
  get tagChooserCategoryId() {
    return this.args.model.board?.category_ids?.[0] || null;
  }

  get showMoveToCategoryField() {
    const boardCategoryCount = this.args.model.board?.category_ids?.length ?? 0;
    if (boardCategoryCount === 1) {
      return !!this.args.model.column?.move_to_category_id;
    }
    return true;
  }

  @action
  onDefaultSortChange(field, value) {
    field.set(value || "priority");
  }

  @action
  onTagChange(field, tags) {
    const tag = tags?.[0];
    field.set(typeof tag === "object" ? tag.name : tag || "");
  }

  @action
  onCategoryChange(field, value) {
    field.set(value);
  }

  @action
  onAssignedModeChange(field, value) {
    field.set(value || "");
  }

  @action
  onAssignedUserChange(field, users) {
    field.set(users?.[0] || "_user");
  }

  @action
  onStatusChange(field, value) {
    field.set(value);
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;
  }

  @action
  async save(data) {
    const columnData = {
      title: data.title.trim() || data.tag_name.trim(),
      icon: data.icon,
      color: data.color || null,
      default_sort: data.default_sort || "priority",
      tag_name: data.tag_name || null,
      move_to_category_id: data.move_to_category_id,
      move_to_assigned: data.move_to_assigned,
      move_to_status: data.move_to_status,
    };
    try {
      await this.args.model.onSave(columnData);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  validateTitle(name, value, { data, addError }) {
    if (isEmpty(value?.trim()) && isEmpty(data.tag_name?.trim())) {
      addError("title", {
        title: i18n("boards.manage.columns.column_title"),
        message: i18n("boards.manage.columns.column_title_required"),
      });
    }
  }

  <template>
    <DModal
      class="discourse-boards-column-settings-modal"
      @closeModal={{@closeModal}}
      @title={{i18n
        (if
          @model.column
          "boards.board.column_settings_title"
          "boards.board.new_column_title"
        )
      }}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form data|>
          <div class="discourse-boards-column-settings-modal__wrapper">
            <form.Section>
              <form.Field
                class="discourse-boards-column-settings__name"
                @format="max"
                @name="title"
                @title={{i18n "boards.manage.columns.name_and_style"}}
                @type="input"
                @validate={{this.validateTitle}}
                as |field|
              >
                <DNameStyleInput
                  @color={{data.color}}
                  @identifier="discourse-boards-column-style"
                  @styleLabel={{styleLabel data.icon}}
                >
                  <:preview>
                    {{dIcon (or data.icon "table-columns") ignoreMissing=true}}
                  </:preview>
                  <:content>
                    <DIconGridPickerContent
                      @iconColorStyle={{iconColorStyle data.color}}
                      @onSelect={{fn form.set "icon"}}
                      @searchPlaceholder={{i18n
                        "boards.manage.columns.icon_search_placeholder"
                      }}
                      @showNames={{true}}
                      @value={{data.icon}}
                    >
                      <form.Field
                        @name="color"
                        @showTitle={{false}}
                        @title={{i18n "boards.manage.columns.color"}}
                        @type="color"
                        as |colorField|
                      >
                        <colorField.Control
                          aria-label={{colorField.title}}
                          @collapseSwatches={{true}}
                          @collapseSwatchesLabel={{i18n
                            "boards.manage.columns.color_palette"
                          }}
                          @colors={{PRESET_COLUMN_COLORS}}
                        />
                      </form.Field>
                    </DIconGridPickerContent>
                  </:content>
                  <:default>
                    <field.Control
                      placeholder={{i18n
                        "boards.manage.columns.column_title_placeholder"
                      }}
                      {{dAutoFocus selectText=true}}
                    />
                  </:default>
                </DNameStyleInput>
              </form.Field>

              <form.Field
                @format="max"
                @name="default_sort"
                @title={{i18n "boards.manage.columns.default_sort"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <ComboBox
                    @content={{COLUMN_SORT_OPTIONS}}
                    @onChange={{fn this.onDefaultSortChange field}}
                    @value={{data.default_sort}}
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @format="max"
                @name="tag_name"
                @title={{i18n "boards.manage.columns.tag"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <MiniTagChooser
                    @onChange={{fn this.onTagChange field}}
                    @options={{hash
                      maximum=1
                      allowCreate=true
                      categoryId=this.tagChooserCategoryId
                    }}
                    @value={{tagToArray data.tag_name}}
                  />
                  <p class="discourse-boards-column-settings__help">
                    {{i18n "boards.manage.columns.tag_help"}}
                  </p>
                </field.Control>
              </form.Field>

              <form.Field
                @format="max"
                @name="move_to_status"
                @title={{i18n "boards.manage.columns.move_to_status"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <ComboBox
                    @content={{STATUS_OPTIONS}}
                    @onChange={{fn this.onStatusChange field}}
                    @options={{hash
                      clearable=true
                      none="boards.manage.columns.move_to_status_none"
                    }}
                    @value={{data.move_to_status}}
                  />
                </field.Control>
              </form.Field>

              {{#if this.showAdvanced}}
                {{#if this.showMoveToCategoryField}}
                  <form.Field
                    @format="max"
                    @name="move_to_category_id"
                    @title={{i18n "boards.manage.columns.move_to_category"}}
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <CategoryChooser
                        @onChange={{fn this.onCategoryChange field}}
                        @options={{hash clearable=true}}
                        @value={{readonly data.move_to_category_id}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                <form.Field
                  @format="max"
                  @name="move_to_assigned"
                  @title={{i18n "boards.manage.columns.move_to_assigned"}}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <ComboBox
                      @content={{ASSIGNED_OPTIONS}}
                      @onChange={{fn this.onAssignedModeChange field}}
                      @options={{hash
                        clearable=true
                        none="boards.manage.columns.move_to_assigned_none"
                      }}
                      @value={{assignedMode data.move_to_assigned}}
                    />
                    {{#if (eq (assignedMode data.move_to_assigned) "_user")}}
                      <EmailGroupUserChooser
                        @onChange={{fn this.onAssignedUserChange field}}
                        @options={{hash maximum=1}}
                        @value={{assignedUserValue data.move_to_assigned}}
                      />
                    {{/if}}
                  </field.Control>
                </form.Field>
              {{/if}}
            </form.Section>
          </div>

          <form.Actions>
            <form.Submit class="discourse-boards-column-settings-modal__save" />
            <form.Button
              class="btn-flat d-modal-cancel discourse-boards-column-settings-modal__cancel"
              @action={{@closeModal}}
              @label="cancel"
            />
            <AdvancedModeToggle
              class="show-advanced"
              @active={{this.showAdvanced}}
              @onToggle={{this.toggleAdvanced}}
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
