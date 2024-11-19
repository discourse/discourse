import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { i18n } from "discourse-i18n";

export function outputExportResult(result) {
  const dialog = getOwnerWithFallback(this).lookup("service:dialog");

  if (result.success) {
    dialog.alert(i18n("admin.export_csv.success"));
  } else {
    dialog.alert(i18n("admin.export_csv.failed"));
  }
}
