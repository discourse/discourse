import { lookup } from "discourse/lib/service";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";
import DialogService from "discourse/dialog-holder/services/dialog";

export function outputExportResult(result) {
  const dialog = lookup(getOwnerWithFallback(this), DialogService);

  if (result.success) {
    dialog.alert(i18n("admin.export_csv.success"));
  } else {
    dialog.alert(i18n("admin.export_csv.failed"));
  }
}
