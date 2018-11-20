import { ajax } from "discourse/lib/ajax";
function exportEntityByType(type, entity, args) {
  return ajax("/export_csv/export_entity.json", {
    method: "POST",
    data: { entity, args }
  });
}

export function exportUserArchive() {
  return exportEntityByType("user", "user_archive")
    .then(function() {
      bootbox.alert(I18n.t("user.download_archive.success"));
    })
    .catch(function() {
      bootbox.alert(I18n.t("user.download_archive.rate_limit_error"));
    });
}

export function exportEntity(entity, args) {
  return exportEntityByType("admin", entity, args);
}
