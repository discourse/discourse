import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BoardsBoardSettings from "./modal/boards-board-settings";

function boardCategories(board) {
  return (board.category_ids || [])
    .map((id) => Category.findById(id))
    .filter(Boolean);
}

export default class BoardsPage extends Component {
  @service modal;
  @service router;
  @service toasts;

  @action
  openNewBoardModal() {
    this.modal.show(BoardsBoardSettings, {
      model: {
        board: null,
        isNew: true,
        onSave: (boardData) => this.createBoard(boardData),
        onDelete: () => {},
      },
    });
  }

  @action
  async createBoard(boardData) {
    const payload = {
      board: {
        ...boardData,
        columns: [],
      },
    };

    const result = await ajax("/boards/api/boards", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify(payload),
    });

    this.toasts.success({
      data: { message: i18n("saved") },
      duration: "short",
    });

    const savedBoard = result.board;
    this.router.transitionTo("boardsBoard", savedBoard.slug, savedBoard.id);
  }

  <template>
    <div class="discourse-boards-manage">
      <DPageHeader
        @titleLabel={{i18n "boards.manage.title"}}
        @descriptionLabel={{i18n "boards.manage.description"}}
        @hideTabs={{true}}
      >
        <:actions as |actions|>
          {{#if @canManageBoards}}
            <actions.Primary
              @action={{this.openNewBoardModal}}
              @icon="plus"
              @label="boards.manage.new"
              class="btn-primary discourse-boards-manage__new-board"
            />
          {{/if}}
        </:actions>
      </DPageHeader>

      <DFilterControls
        @array={{@boards}}
        @searchableProps={{array "name"}}
        @textFilterQueryParam="filter"
        @inputPlaceholder={{i18n "boards.filter_boards"}}
        @noResultsMessage={{i18n "boards.filter_boards_no_results"}}
        @showCustomEmptyState={{true}}
        @minItemsForFilter={{1}}
      >
        <:content as |filteredBoards|>
          <div class="discourse-boards-boards-grid">
            {{#each filteredBoards as |board|}}
              <div class="discourse-boards-board-card">
                <div class="discourse-boards-board-card__header">
                  <LinkTo
                    @route="boardsBoard"
                    @models={{array board.slug board.id}}
                    class="discourse-boards-board-card__name"
                  >
                    {{board.fancyTitle}}
                  </LinkTo>
                </div>

                {{#if (or board.category_ids.length board.tag_names.length)}}
                  <div class="discourse-boards-board-card__constraints">
                    {{#each (boardCategories board) as |category|}}
                      {{dBoundCategoryLink category link=false}}
                    {{/each}}
                    {{#if board.tag_names.length}}
                      <div class="list-tags">
                        {{dDiscourseTags null tags=board.tag_names}}
                      </div>
                    {{/if}}
                  </div>
                {{/if}}

                <div class="discourse-boards-board-card__columns">
                  {{#if board.columns.length}}
                    {{#each board.columns as |column|}}
                      <span class="discourse-boards-column-pill">
                        {{#if column.icon}}
                          {{dIcon column.icon}}
                        {{/if}}
                        {{column.fancyTitle}}
                      </span>
                    {{/each}}
                  {{else}}
                    <span class="discourse-boards-board-card__no-columns">
                      {{i18n "boards.manage.no_columns"}}
                    </span>
                  {{/if}}
                </div>

                <div class="discourse-boards-board-card__footer">
                  <DUserLink
                    class="discourse-boards-board-card__creator discourse-boards-badge"
                    @user={{board.created_by}}
                  >
                    {{i18n "boards.board.created_by"}}
                    {{dAvatar board.created_by imageSize="micro"}}
                  </DUserLink>

                  <span class="discourse-boards-badge">
                    {{i18n
                      "boards.manage.column_count"
                      count=board.columns.length
                    }}
                  </span>
                  {{#if (eq board.card_style "simple")}}
                    <span class="discourse-boards-badge">
                      {{i18n "boards.manage.card_style_simple"}}
                    </span>
                  {{/if}}
                  {{#unless board.anonymous_can_read}}
                    <span
                      class="discourse-boards-badge discourse-boards-badge--restricted"
                      title={{i18n "boards.manage.restricted_access"}}
                    >
                      {{dIcon "lock"}}
                    </span>
                  {{/unless}}
                </div>
              </div>
            {{/each}}
          </div>
        </:content>
        <:customEmptyState>
          <div class="discourse-boards-boards-empty">
            {{dIcon "table-columns"}}
            <h3>{{i18n "boards.manage.empty_title"}}</h3>
            {{#if @canManageBoards}}
              <p>{{i18n "boards.manage.get_started"}}</p>
              <DButton
                @action={{this.openNewBoardModal}}
                @icon="plus"
                @label="boards.manage.new"
                class="btn-primary"
              />
            {{/if}}
          </div>
        </:customEmptyState>
      </DFilterControls>
    </div>
  </template>
}
