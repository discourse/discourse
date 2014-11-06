import ModalFunctionality from 'discourse/mixins/modal-functionality';

import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  needs: ['modal'],

  showGoogleSearch: function() {
    return !Discourse.SiteSettings.login_required;
  }.property()
});
