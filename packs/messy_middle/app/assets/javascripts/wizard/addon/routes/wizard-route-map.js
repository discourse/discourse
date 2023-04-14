export default function () {
  this.route("wizard", function () {
    this.route("step", { path: "/steps/:step_id" });
  });
}
