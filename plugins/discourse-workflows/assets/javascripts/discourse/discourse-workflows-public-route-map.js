export default function () {
  this.route("workflows-form", { path: "/workflows/form/:uuid" });
  this.route("workflows-form-test", { path: "/workflows/form-test/:token" });
}
