export default function () {
  this.route("hamilton", function () {
    this.route("docs", function () {
      this.route("guide");
      this.route("roadmap");
    });
  });
}
