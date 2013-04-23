/**
  The view that displays the number of users at each trust level
  on the admin dashboard.

  @class AdminReportTrustLevelsView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminReportTrustLevelsView = Discourse.View.extend({
  templateName: 'admin/templates/reports/trust_levels_report',
  tagName: 'tbody'
});