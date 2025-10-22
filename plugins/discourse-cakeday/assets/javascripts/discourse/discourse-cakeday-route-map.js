export default function () {
  this.route("cakeday", { resetNamespace: true }, function () {
    this.route("birthdays", function () {
      this.route("today");
      this.route("tomorrow");
      this.route("upcoming");
      this.route("all");
    });

    this.route("anniversaries", function () {
      this.route("today");
      this.route("tomorrow");
      this.route("upcoming");
      this.route("all");
    });
  });
}
