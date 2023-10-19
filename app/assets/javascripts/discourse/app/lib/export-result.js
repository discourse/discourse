import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import I18n from "discourse-i18n";

export function outputExportResult(result) {
  const dialog = getOwnerWithFallback(this).lookup("service:dialog");

  if (result.success) {
    dialog.alert(I18n.t("admin.export_csv.success"));
  } else {
    dialog.alert(I18n.t("admin.export_csv.failed"));
  }
}
