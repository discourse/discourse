export default function () {
  this.route("workflows-form", {
    path: "/workflows/form/:uuid",
    bundleName: "workflows-form",
  });
  this.route("workflows-form-test", {
    path: "/workflows/form-test/:token",
    bundleName: "workflows-form",
  });
}
