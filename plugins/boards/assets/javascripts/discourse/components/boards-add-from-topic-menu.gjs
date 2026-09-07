import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import Board from "discourse/plugins/boards/discourse/models/board";
import BoardsAddFromTopicColumnSubmenu from "./boards-add-from-topic-column-submenu";

const SKELETON_ROWS = Array.from({ length: 3 });

const BoardSkeleton = <template>
  <div
    class="discourse-boards-add-from-topic-menu__skeleton"
    aria-hidden="true"
  >
    <div class="discourse-boards-add-from-topic-menu__skeleton-label"></div>
    <div class="discourse-boards-add-from-topic-menu__skeleton-icon"></div>
  </div>
</template>;

export default class BoardsAddFromTopicMenu extends Component {
  @service menu;

  @tracked boards = [];
  @tracked loading = true;

  skeletonRows = SKELETON_ROWS;
  #requestedBoards = false;

  @action
  loadBoards() {
    if (this.#requestedBoards) {
      return;
    }

    this.#requestedBoards = true;
    this.#fetchBoards();
  }

  async #fetchBoards() {
    try {
      const result = await ajax(
        `/boards/api/boards/available?topic_id=${this.args.data.topic.id}&allowed_permissions=edit,manage`
      );
      this.boards = result.boards
        .filter((board) => board.columns?.length)
        .map((board) => Board.create(board));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  openBoardSubmenu(board, event) {
    return this.menu.show(event.currentTarget, {
      identifier: "discourse-boards-add-from-topic-column-menu",
      component: BoardsAddFromTopicColumnSubmenu,
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      data: { board, topic: this.args.data?.topic },
      onClose: (data) => {
        if (data?.cardSaved) {
          this.args.close();
        }
      },
    });
  }

  get availableBoards() {
    return this.boards.filter((board) => !board.topic_is_member);
  }

  get alreadyAddedBoards() {
    return this.boards.filter((board) => board.topic_is_member);
  }

  <template>
    <DDropdownMenu
      class="discourse-boards-add-from-topic-menu"
      {{didInsert this.loadBoards}}
      as |dropdown|
    >
      {{#if this.loading}}
        {{#each this.skeletonRows}}
          <dropdown.item>
            <BoardSkeleton />
          </dropdown.item>
        {{/each}}
      {{else}}
        {{#if this.boards.length}}
          {{#if this.availableBoards.length}}
            <dropdown.subheader>
              {{i18n "boards.topic_footer.add_to_board"}}
            </dropdown.subheader>
            {{#each this.availableBoards as |board|}}
              <dropdown.item
                class="discourse-boards-add-from-topic-menu__board-item"
                {{on
                  "mouseenter"
                  (fn this.openBoardSubmenu board)
                  passive=true
                }}
              >
                <DButton
                  @actionParam={{board}}
                  @action={{this.openBoardSubmenu}}
                  @forwardEvent={{true}}
                  @suffixIcon="angle-right"
                  @translatedLabel={{board.fancyTitle}}
                  class="btn-transparent discourse-boards-add-from-topic-menu__board"
                />
              </dropdown.item>
            {{/each}}
          {{/if}}
          {{#if this.alreadyAddedBoards.length}}
            <dropdown.subheader>
              {{i18n "boards.topic_footer.already_added"}}
            </dropdown.subheader>
            {{#each this.alreadyAddedBoards as |board|}}
              <dropdown.item
                class="discourse-boards-add-from-topic-menu__board-item"
                {{on
                  "mouseenter"
                  (fn this.openBoardSubmenu board)
                  passive=true
                }}
              >
                <DButton
                  @actionParam={{board}}
                  @action={{this.openBoardSubmenu}}
                  @forwardEvent={{true}}
                  @suffixIcon="angle-right"
                  @translatedLabel={{board.fancyTitle}}
                  class="btn-transparent discourse-boards-add-from-topic-menu__board"
                />
              </dropdown.item>
            {{/each}}
          {{/if}}
        {{else}}
          <dropdown.item class="discourse-boards-add-from-topic-menu__empty">
            {{i18n "boards.topic_footer.no_boards"}}
          </dropdown.item>
        {{/if}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
