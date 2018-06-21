export default Ember.Controller.extend({
  loading: false,
  period: "all",
  searchType: "all",

  searchTypeOptions: [
    {
      id: "all",
      name: I18n.t("admin.logs.search_logs.types.all_search_types")
    },
    { id: "header", name: I18n.t("admin.logs.search_logs.types.header") },
    { id: "full_page", name: I18n.t("admin.logs.search_logs.types.full_page") }
  ]
});
