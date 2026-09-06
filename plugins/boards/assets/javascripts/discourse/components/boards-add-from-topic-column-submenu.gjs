import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import BoardsConstraintFix from "./modal/boards-constraint-fix";

export default class BoardsAddFromTopicColumnSubmenu extends Component {
  @service messageBus;
  @service modal;
  @service toasts;

  @action
  async addToColumn(column) {
    const response = await this.#checkConstraints(column);

    if (!response) {
      return;
    }

    if (response.constraints_need_fixing) {
      return this.#onConstraintMismatch(column, response);
    }

    await this.#completeAddToColumn(column);
  }

  @action
  async removeFromColumn(column) {
    try {
      await ajax(
        `/boards/api/boards/${this.args.data.board.id}/cards/${column.topic_card_id}`,
        {
          type: "DELETE",
        }
      );

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("boards.board.removed_topic_from_board", {
            boardName: this.args.data.board.unicode_name,
            columnName: column.unicode_title,
          }),
        },
      });

      this.args.close({ data: { cardSaved: true } });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #checkConstraints(column) {
    try {
      const response = await ajax(
        `/boards/api/boards/${this.args.data.board.id}/check-constraint-mismatches`,
        {
          method: "PUT",
          data: {
            topic_id: this.args.data.topic.id,
            target_column_id: column.id,
          },
        }
      );
      return response;
    } catch (error) {
      popupAjaxError(error);
      return null;
    }
  }

  #onConstraintMismatch(column, response) {
    const mismatches = {
      needsTags: response.tags_needed.length > 0,
      needsCategory: response.categories_needed.length > 0,
      boardTagNames: response.tags_needed,
      boardCategoryIds: response.categories_needed,
    };

    this.modal.show(BoardsConstraintFix, {
      model: {
        topic: this.args.data.topic,
        board: this.args.data.board,
        column,
        mismatches,
        onConfirm: (result) => this.#completeAddToColumn(column, result),
      },
    });
  }

  async #completeAddToColumn(column, constraintFixResult = null) {
    const data = {
      client_id: this.messageBus.clientId,
      card: {
        column_id: column.id,
        topic_id: this.args.data.topic.id,
      },
    };

    if (constraintFixResult) {
      data.constraint_fix = constraintFixResult;
    }

    try {
      await ajax(`/boards/api/boards/${this.args.data.board.id}/cards`, {
        type: "POST",
        data,
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("boards.board.added_topic_to_board", {
            boardName: this.args.data.board.unicode_name,
            columnName: column.unicode_title,
          }),
        },
      });

      this.args.close({ data: { cardSaved: true } });
    } catch (error) {
      popupAjaxError(error);
      return;
    }
  }

  get availableColumns() {
    return this.args.data.board.columns.filter(
      (column) => !column.topic_is_member
    );
  }

  get alreadyAddedColumns() {
    return this.args.data.board.columns.filter(
      (column) => column.topic_is_member
    );
  }

  columnStyle(column) {
    if (!isValidHex(column.color)) {
      return null;
    }

    return trustHTML(
      `--discourse-boards-column-icon-color: #${normalizeHex(column.color)};`
    );
  }

  <template>
    <DDropdownMenu
      class="discourse-boards-add-from-topic-column-menu"
      as |dropdown|
    >
      {{#if this.availableColumns.length}}
        <dropdown.subheader>
          {{@data.board.unicode_name}}
        </dropdown.subheader>
        {{#each this.availableColumns as |column|}}
          <dropdown.item>
            <DButton
              @action={{fn this.addToColumn column}}
              @icon={{column.icon}}
              @translatedLabel={{column.fancyTitle}}
              style={{this.columnStyle column}}
              class="btn-transparent discourse-boards-add-from-topic-column-menu__column"
            />
          </dropdown.item>
        {{/each}}
      {{/if}}
      {{#if this.alreadyAddedColumns.length}}
        <dropdown.subheader>
          {{i18n "boards.topic_footer.already_added"}}
        </dropdown.subheader>
        {{#each this.alreadyAddedColumns as |column|}}
          <dropdown.item>
            <DButton
              @action={{fn this.removeFromColumn column}}
              @icon={{column.icon}}
              @translatedLabel={{column.fancyTitle}}
              @suffixIcon="xmark"
              style={{this.columnStyle column}}
              class="btn-transparent discourse-boards-add-from-topic-column-menu__column"
            />
          </dropdown.item>
        {{/each}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
