import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import Board from "../models/board";

export default class BoardsBoardCardRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return this.controller?.model?.board?.fancyTitle;
  }

  model(params) {
    return ajax(`/boards/api/boards/${params.id}.json`).then((data) =>
      Board.createPayload({
        ...data,
        initialCardId: parseInt(params.card_id, 10),
      })
    );
  }

  afterModel(model, transition) {
    const board = model.board;
    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith(
        "boardsBoardCard",
        board.slug,
        board.id,
        transition.to.params.card_id
      );
    }
  }
}
