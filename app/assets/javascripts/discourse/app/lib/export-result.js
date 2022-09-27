import I18n from "I18n";
import { getOwner } from "discourse-common/lib/get-owner";

export function outputExportResult(result) {
  const dialog = getOwner(this).lookup("service:dialog");

  if (result.success) {
    dialog.alert(I18n.t("admin.export_csv.success"));
  } else {
    dialog.alert(I18n.t("admin.export_csv.failed"));
  }
}
