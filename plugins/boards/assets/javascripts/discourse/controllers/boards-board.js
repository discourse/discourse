import Controller from "@ember/controller";

export default class BoardsBoardController extends Controller {
  queryParams = ["card"];
  card = null;
}
