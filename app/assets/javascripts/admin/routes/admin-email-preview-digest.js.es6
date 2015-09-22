export default Discourse.Route.extend({

  model() {
    return Discourse.EmailPreview.findDigest();
  },

  afterModel(model) {
    const controller = this.controllerFor('adminEmailPreviewDigest');
    controller.setProperties({
      model: model,
      lastSeen: moment().subtract(7, 'days').format('YYYY-MM-DD'),
      showHtml: true
    });
  }

});
