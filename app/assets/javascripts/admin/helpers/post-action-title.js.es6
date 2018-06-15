function postActionTitle([id, nameKey]) {
  let title = I18n.t(`admin.flags.short_names.${nameKey}`, {
    defaultValue: null
  });

  // TODO: We can remove this once other translations have been updated
  if (!title) {
    return I18n.t(`admin.flags.summary.action_type_${id}`, { count: 1 });
  }

  return title;
}

export default Ember.Helper.helper(postActionTitle);
