export function outputExportResult(result) {
  if (result.success) {
    bootbox.alert(I18n.t("admin.export_csv.success"));
  } else {
    bootbox.alert(I18n.t("admin.export_csv.failed"));
  }
}
