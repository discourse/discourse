import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { columnColorVariable } from "../lib/boards-column-helpers";
import { membershipCardUrl } from "../lib/boards-topic-pill";

export default class BoardsMenu extends Component {
  get memberships() {
    return this.args.data.memberships.map((membership) => ({
      ...membership,
      fancyTitle: membership.unicode_board_name || membership.board_name,
      cards: membership.cards.map((card) => ({
        ...card,
        fancyTitle: card.unicode_column_title || card.column_title,
      })),
    }));
  }

  @action
  goToBoard(membership) {
    this.args.close();
    DiscourseURL.routeTo(membershipCardUrl(membership));
  }

  <template>
    <DDropdownMenu as |dropdown|>
      {{#each this.memberships as |membership|}}
        <dropdown.item>
          <DButton
            @action={{fn this.goToBoard membership}}
            class="btn-transparent discourse-boards-boards-menu__item --with-description"
          >
            <div class="discourse-boards-boards-menu__item-texts">
              <span
                class="discourse-boards-boards-menu__item-label"
              >{{membership.fancyTitle}}</span>
              {{#each membership.cards as |card|}}
                <span
                  class="discourse-boards-boards-menu__column"
                  style={{columnColorVariable card.column_color}}
                >
                  {{#if card.column_icon}}
                    {{dIcon card.column_icon}}
                  {{/if}}
                  {{card.fancyTitle}}
                </span>
              {{/each}}
            </div>
          </DButton>
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
