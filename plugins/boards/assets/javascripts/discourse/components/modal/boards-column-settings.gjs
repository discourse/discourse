import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  ASSIGNED_OPTIONS,
  assignedMode,
  assignedUserValue,
  COLUMN_SORT_OPTIONS,
  PRESET_COLUMN_COLORS,
  STATUS_OPTIONS,
  tagToArray,
} from "../../lib/boards-column-helpers";
import BoardsEditableTitle from "../boards-editable-title";

export default class BoardsColumnSettings extends Component {
  @tracked showAdvanced = false;

  get isNew() {
    return !this.args.model.column;
  }

  @cached
  get formData() {
    const column = this.args.model.column;
    if (column) {
      return {
        title: column.title || "",
        icon: column.icon || null,
        color: column.color || null,
        default_sort: column.default_sort || "priority",
        tag_name: column.tag_name || "",
        move_to_category_id: column.move_to_category_id || null,
        move_to_assigned: column.move_to_assigned || "",
        move_to_status: column.move_to_status || "",
      };
    }
    return {
      title: "",
      icon: null,
      color: null,
      default_sort: "priority",
      tag_name: "",
      move_to_category_id: null,
      move_to_assigned: "",
      move_to_status: "",
    };
  }

  get statusOptions() {
    return STATUS_OPTIONS;
  }

  get sortOptions() {
    return COLUMN_SORT_OPTIONS;
  }

  get assignedOptions() {
    return ASSIGNED_OPTIONS;
  }

  // NOTE: We are aware this is not ideal because a board
  // can have multiple categories, but we only support one
  // for now because server-side the tag search is limited
  // to one category at a time.
  get tagChooserCategoryId() {
    return this.args.model.board?.category_ids?.[0] || null;
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

  get showMoveToCategoryField() {
    const boardCategoryCount = this.args.model.board?.category_ids?.length ?? 0;
    if (boardCategoryCount === 1) {
      return !!this.args.model.column?.move_to_category_id;
    }
    return true;
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
    if (isEmpty(value) && isEmpty(data.tag_name)) {
      addError("title", {
        title: i18n("boards.manage.columns.column_title"),
        message: i18n("boards.manage.columns.column_title_required"),
      });
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @hideHeader={{true}}
      class="discourse-boards-column-settings-modal"
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form data|>
          <BoardsEditableTitle
            @form={{form}}
            @name="title"
            @title={{i18n "boards.manage.columns.column_title"}}
            @placeholder={{i18n
              "boards.manage.columns.column_title_placeholder"
            }}
            @validate={{this.validateTitle}}
            @onClose={{@closeModal}}
          />
          <div class="discourse-boards-column-settings-modal__wrapper">
            <form.Section>
              <form.Field
                @name="icon"
                @title={{i18n "boards.manage.columns.icon"}}
                @format="max"
                @type="icon"
                as |field|
              >
                <field.Control />
              </form.Field>

              <form.Field
                @name="color"
                @title={{i18n "boards.manage.columns.color"}}
                @format="max"
                @type="color"
                as |field|
              >
                <field.Control @colors={{PRESET_COLUMN_COLORS}} />
              </form.Field>

              <form.Field
                @name="default_sort"
                @title={{i18n "boards.manage.columns.default_sort"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <ComboBox
                    @value={{data.default_sort}}
                    @content={{this.sortOptions}}
                    @onChange={{fn this.onDefaultSortChange field}}
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @name="tag_name"
                @title={{i18n "boards.manage.columns.tag"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <MiniTagChooser
                    @value={{tagToArray data.tag_name}}
                    @onChange={{fn this.onTagChange field}}
                    @options={{hash
                      maximum=1
                      allowCreate=true
                      categoryId=this.tagChooserCategoryId
                    }}
                  />
                  <p class="discourse-boards-column-settings__help">
                    {{i18n "boards.manage.columns.tag_help"}}
                  </p>
                </field.Control>
              </form.Field>

              <form.Field
                @name="move_to_status"
                @title={{i18n "boards.manage.columns.move_to_status"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <ComboBox
                    @value={{data.move_to_status}}
                    @content={{this.statusOptions}}
                    @onChange={{fn this.onStatusChange field}}
                    @options={{hash
                      clearable=true
                      none="boards.manage.columns.move_to_status_none"
                    }}
                  />
                </field.Control>
              </form.Field>

              {{#if this.showAdvanced}}
                {{#if this.showMoveToCategoryField}}
                  <form.Field
                    @name="move_to_category_id"
                    @title={{i18n "boards.manage.columns.move_to_category"}}
                    @format="max"
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <CategoryChooser
                        @value={{data.move_to_category_id}}
                        @onChange={{fn this.onCategoryChange field}}
                        @options={{hash clearable=true}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                <form.Field
                  @name="move_to_assigned"
                  @title={{i18n "boards.manage.columns.move_to_assigned"}}
                  @format="max"
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <ComboBox
                      @value={{assignedMode data.move_to_assigned}}
                      @content={{this.assignedOptions}}
                      @onChange={{fn this.onAssignedModeChange field}}
                      @options={{hash
                        clearable=true
                        none="boards.manage.columns.move_to_assigned_none"
                      }}
                    />
                    {{#if (eq (assignedMode data.move_to_assigned) "_user")}}
                      <EmailGroupUserChooser
                        @value={{assignedUserValue data.move_to_assigned}}
                        @onChange={{fn this.onAssignedUserChange field}}
                        @options={{hash maximum=1}}
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
            <DButton
              @action={{this.toggleAdvanced}}
              @icon="gear"
              @title={{if
                this.showAdvanced
                "boards.manage.columns.hide_advanced"
                "boards.manage.columns.show_advanced"
              }}
              class="btn-default show-advanced"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
