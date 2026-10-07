export default function () {
  this.route("boards");
  this.route("boardsBoard", { path: "/boards/:slug/:id" });
  this.route("boardsBoardConfigure", {
    path: "/boards/:slug/:id/configure",
  });
  this.route("boardsBoardCard", {
    path: "/boards/:slug/:id/cards/:card_id",
  });
}
