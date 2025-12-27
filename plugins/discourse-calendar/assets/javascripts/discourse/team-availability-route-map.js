export default function () {
  this.route("availability");
  this.route("availability-group", { path: "/availability/:group_name" });
}
