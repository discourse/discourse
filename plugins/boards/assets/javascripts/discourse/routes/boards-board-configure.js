import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import Board from "../models/board";

export default class BoardsBoardConfigureRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return this.controller?.model?.board?.fancyTitle;
  }

  model(params) {
    return ajax(`/boards/api/boards/${params.id}.json`).then((data) =>
      Board.createPayload({ ...data, openBoardSettings: true })
    );
  }

  afterModel(model, transition) {
    const board = model.board;

    if (board && !board.can_manage) {
      this.router.replaceWith("boardsBoard", board.slug, board.id);
      return;
    }

    if (board?.slug && transition.to.params.slug !== board.slug) {
      this.router.replaceWith("boardsBoardConfigure", board.slug, board.id);
    }
  }
}
