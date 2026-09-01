import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import Board from "../models/board";

export default class BoardsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("boards.manage.title");
  }

  async model() {
    const data = await ajax("/boards/api/boards.json");
    return data.boards.map((board) => Board.create(board));
  }
}
