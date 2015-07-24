function exportEntityByType(type, entity) {
  return Discourse.ajax("/export_csv/export_entity.json", {
    method: 'POST',
    data: {entity_type: type, entity}
  });
}

export function exportUserArchive() {
  return exportEntityByType('user', 'user_archive').then(function() {
    bootbox.alert(I18n.t("admin.export_csv.success"));
  }).catch(function() {
    bootbox.alert(I18n.t("admin.export_csv.rate_limit_error"));
  });
}


export function exportEntity(entity) {
  return exportEntityByType('admin', entity);
}
