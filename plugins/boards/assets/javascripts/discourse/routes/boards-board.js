import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { sortCardsForColumn } from "../lib/boards-card-ordering";
import Board from "../models/board";

export default class BoardsBoardRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    card: { refreshModel: true },
  };

  titleToken() {
    return this.controller?.model?.board?.fancyTitle;
  }

  model(params, transition) {
    return ajax(`/boards/api/boards/${params.id}.json`).then((data) =>
      Board.createPayload({
        ...data,
        highlightCardId: parseInt(transition.to.queryParams.card, 10) || null,
      })
    );
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith("boardsBoard", board.slug, board.id, {
        queryParams: { card: transition.to.queryParams.card },
      });
    }

    model.board.columns = model.board.columns.map((col) => {
      col.cards = sortCardsForColumn(col, col.cards || []);
      return col;
    });
  }
}
