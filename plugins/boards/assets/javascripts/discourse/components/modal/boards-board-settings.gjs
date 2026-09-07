import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import discourseDebounce from "discourse/lib/debounce";
import { slugify } from "discourse/lib/utilities";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { eq, or } from "discourse/truth-helpers";
import DAccessControlField from "discourse/ui-kit/d-access-control-field";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import BoardsEditableTitle from "../boards-editable-title";

const CONSTRAINT_TYPE_OPTIONS = [
  {
    id: "categories",
    name: i18n("boards.manage.constraint_categories"),
  },
  { id: "tags", name: i18n("boards.manage.constraint_tags") },
  {
    id: "categories_and_tags",
    name: i18n("boards.manage.constraint_categories_and_tags"),
  },
];

function inferConstraintType(categoryIds, tagNames) {
  const hasCats = categoryIds?.length > 0;
  const hasTags = tagNames?.length > 0;
  if (hasCats && hasTags) {
    return "categories_and_tags";
  } else if (hasCats) {
    return "categories";
  } else if (hasTags) {
    return "tags";
  }
  return null;
}

const CARD_STYLE_OPTIONS = [
  {
    id: "detailed",
    name: i18n("boards.manage.card_style_detailed"),
  },
  { id: "simple", name: i18n("boards.manage.card_style_simple") },
];

export default class BoardsBoardSettings extends Component {
  @service dialog;
  @service site;
  @service siteSettings;

  @tracked showAdvanced = false;

  constraintWarning = null;
  reloadAfterSave = false;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._constraintCheckTimer);
  }

  @cached
  get formData() {
    const board = this.args.model.board;

    // Existing board
    if (board) {
      return {
        name: board.name || "",
        slug: board.slug || "",
        constraint_type: inferConstraintType(
          board.category_ids,
          board.tag_names
        ),
        category_ids: board.category_ids || [],
        tag_names: board.tag_names || [],
        card_style: board.card_style || "detailed",
        show_tags: board.show_tags ?? false,
        show_topic_thumbnail: board.show_topic_thumbnail ?? false,
        require_confirmation: board.require_confirmation ?? false,
        acl: board.acl,
      };
    }

    // New board
    return {
      name: "",
      slug: "",
      constraint_type: null,
      category_ids: [],
      tag_names: [],
      card_style: "detailed",
      show_tags: true,
      show_topic_thumbnail: false,
      require_confirmation: false,
      acl: this.#buildDefaultAcl(),
    };
  }

  get isNew() {
    return this.args.model.isNew;
  }

  get boardsManageBoardAllowedGroupIds() {
    return this.siteSettings.groupSettingArray(
      "boards_manage_board_allowed_groups"
    );
  }

  get aclTarget() {
    return {
      type: "Boards::Board",
      id: this.args.model.board?.id,
      name: i18n("boards.manage.board"),
    };
  }

  get slugPlaceholder() {
    const boardName = this.formApi.get("name");

    if (isEmpty(boardName)) {
      return "";
    }

    return slugify(boardName);
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;
  }

  @action
  selectedCategories(categoryIds) {
    return (categoryIds || [])
      .map((id) => this.site.categories?.find((c) => c.id === id))
      .filter(Boolean);
  }

  @action
  onConstraintTypeChange(type, { set }) {
    set("constraint_type", type);
    if (!type) {
      set("category_ids", []);
      set("tag_names", []);
    } else if (type === "categories") {
      set("tag_names", []);
    } else if (type === "tags") {
      set("category_ids", []);
    }
    this._checkConstraints(
      type === "tags" || !type ? [] : null,
      type === "categories" || !type ? [] : null
    );
  }

  @action
  onCategoriesChange(field, categories) {
    const ids = categories?.map((c) => c.id) || [];
    field.set(ids);
    this._checkConstraints(ids, null);
  }

  @action
  onTagsChange(tags, { set }) {
    const names = tags.map((t) => (typeof t === "string" ? t : t.name));
    set("tag_names", names);
    this._checkConstraints(null, names);
  }

  _checkConstraints(categoryIds, tagNames) {
    if (this.isNew) {
      return;
    }
    cancel(this._constraintCheckTimer);
    this._constraintCheckTimer = discourseDebounce(
      this,
      this._fetchConstraintPreview,
      categoryIds,
      tagNames,
      500
    );
  }

  async _fetchConstraintPreview(categoryIds, tagNames) {
    const boardId = this.args.model.board?.id;
    if (!boardId) {
      return;
    }

    try {
      const result = await ajax(
        `/boards/api/boards/${boardId}/constraint-preview`,
        {
          type: "POST",
          data: {
            category_ids: categoryIds ?? this.formApi?.get("category_ids"),
            tag_names: tagNames ?? this.formApi?.get("tag_names"),
          },
        }
      );
      this.constraintWarning =
        result.cards_to_remove > 0
          ? i18n("boards.manage.constraint_warning", {
              count: result.cards_to_remove,
            })
          : null;
    } catch {
      this.constraintWarning = null;
    }
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  async save(data) {
    if (this.constraintWarning) {
      this.dialog.confirm({
        message: this.constraintWarning,
        didConfirm: () => this._performSave(data),
      });
      return;
    }

    await this._performSave(data);
  }

  async _performSave(data) {
    try {
      await this.args.model.onSave(data);
      this.args.closeModal({ reloadAfterSave: this.reloadAfterSave });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onDelete() {
    this.args.model.onDelete();
    this.args.closeModal();
  }

  @action
  transformPermissionOptions(options) {
    const viewOption = options.find((option) => option.id === "view");
    viewOption.description = i18n(
      "boards.manage.board_access_permission_viewer_description"
    );

    const editOption = options.find((option) => option.id === "edit");
    editOption.description = i18n(
      "boards.manage.board_access_permission_editor_description"
    );

    options.push({
      id: "manage",
      level: 3,
      name: i18n("boards.manage.board_access_permission_manager"),
      description: i18n(
        "boards.manage.board_access_permission_manager_description"
      ),
    });

    return options;
  }

  @action
  aclChanged(acl) {
    this.reloadAfterSave = false;
    this.formApi.set("acl", acl);
  }

  @action
  accessLossConfirmed() {
    this.reloadAfterSave = true;
  }

  #buildDefaultAcl() {
    const defaultAcl = [];

    this.boardsManageBoardAllowedGroupIds.forEach((groupId) => {
      const group = this.site.groupsById[groupId];
      if (group) {
        defaultAcl.push({
          type: "group",
          id: group.id,
          permission: "manage",
          display_name: group.full_name,
        });
      }
    });

    if (
      !this.boardsManageBoardAllowedGroupIds.includes(
        AUTO_GROUPS.logged_in_users.id
      )
    ) {
      defaultAcl.push({
        type: "group",
        id: AUTO_GROUPS.logged_in_users.id,
        permission: "view",
        display_name: this.site.groupFullName(AUTO_GROUPS.logged_in_users.id),
      });
    }

    return defaultAcl;
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @hideHeader={{true}}
      @inline={{@inline}}
      class="discourse-boards-board-settings-modal"
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form data|
        >
          <BoardsEditableTitle
            @form={{form}}
            @name="name"
            @title={{i18n "boards.manage.name"}}
            @placeholder={{i18n "boards.manage.name_placeholder"}}
            @onClose={{@closeModal}}
            @showClose={{true}}
          />
          <div class="discourse-boards-board-settings-modal__wrapper">

            <form.Section>
              <form.Field
                @name="slug"
                @title={{i18n "boards.manage.slug"}}
                @format="max"
                @type="input"
                @placeholder={{this.slugPlaceholder}}
                as |field|
              >
                <field.Control />
              </form.Field>
            </form.Section>

            <form.Section>
              <DAccessControlField
                @form={{form}}
                @title={{i18n "boards.manage.board_access"}}
                @aclTarget={{this.aclTarget}}
                @description={{i18n "boards.manage.board_access_description"}}
                @transformPermissionOptions={{this.transformPermissionOptions}}
                @onChange={{this.aclChanged}}
                @onAccessLossConfirmed={{this.accessLossConfirmed}}
                @mustHavePermissions={{array "manage"}}
              />
            </form.Section>

            <form.Section>
              <form.Field
                @name="constraint_type"
                @title={{i18n "boards.manage.constrain_board_by"}}
                @description={{i18n "boards.manage.constraint_help"}}
                @format="max"
                @type="select"
                @onSet={{this.onConstraintTypeChange}}
                as |field|
              >
                <field.Control as |select|>
                  {{#each CONSTRAINT_TYPE_OPTIONS as |option|}}
                    <select.Option
                      @value={{option.id}}
                    >{{option.name}}</select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>

              {{#if
                (or
                  (eq data.constraint_type "categories")
                  (eq data.constraint_type "categories_and_tags")
                )
              }}
                <form.Field
                  @name="category_ids"
                  @title={{i18n "boards.manage.board_categories_constraint"}}
                  @format="max"
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <CategorySelector
                      @categories={{this.selectedCategories data.category_ids}}
                      @onChange={{fn this.onCategoriesChange field}}
                    />
                  </field.Control>
                </form.Field>
              {{/if}}

              {{#if
                (or
                  (eq data.constraint_type "tags")
                  (eq data.constraint_type "categories_and_tags")
                )
              }}
                <form.Field
                  @name="tag_names"
                  @title={{i18n "boards.manage.board_tags_constraint"}}
                  @format="max"
                  @type="tag-chooser"
                  @onSet={{this.onTagsChange}}
                  as |field|
                >
                  <field.Control
                    @showAllTags={{true}}
                    @excludeSynonyms={{true}}
                    @allowCreate={{true}}
                  />
                </form.Field>
              {{/if}}

              {{#if this.constraintWarning}}
                <form.Alert @type="warning">
                  {{this.constraintWarning}}
                </form.Alert>
              {{/if}}
            </form.Section>
            <form.Section>
              <form.Field
                @name="card_style"
                @title={{i18n "boards.manage.card_style"}}
                @description={{i18n "boards.manage.card_style_description"}}
                @format="max"
                @type="select"
                as |field|
              >
                <field.Control as |select|>
                  {{#each CARD_STYLE_OPTIONS as |option|}}
                    <select.Option
                      @value={{option.id}}
                    >{{option.name}}</select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>

            </form.Section>

            {{#if this.showAdvanced}}
              <form.Section @title={{i18n "boards.manage.advanced_settings"}}>

                <form.Field
                  @name="show_tags"
                  @title={{i18n "boards.manage.show_tags"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @name="show_topic_thumbnail"
                  @title={{i18n "boards.manage.show_topic_thumbnail"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @name="require_confirmation"
                  @title={{i18n "boards.manage.require_confirmation"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </form.Field>
              </form.Section>
            {{/if}}
          </div>

          <form.Actions>
            <form.Submit
              class="discourse-boards-board-settings-modal__save-board"
            />
            {{#unless this.isNew}}
              <form.Button
                class="btn-danger discourse-boards-board-settings-modal__delete-board"
                @action={{this.onDelete}}
                @label="boards.board.delete_board"
              />
            {{/unless}}

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
