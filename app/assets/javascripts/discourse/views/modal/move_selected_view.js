(function() {

  window.Discourse.MoveSelectedView = window.Discourse.ModalBodyView.extend(Discourse.Presence, {
    templateName: 'modal/move_selected',
    title: Em.String.i18n('topic.move_selected.title'),
    saving: false,
    selectedCount: (function() {
      if (!this.get('selectedPosts')) {
        return 0;
      }
      return this.get('selectedPosts').length;
    }).property('selectedPosts'),
    buttonDisabled: (function() {
      if (this.get('saving')) {
        return true;
      }
      return this.blank('topicName');
    }).property('saving', 'topicName'),
    buttonTitle: (function() {
      if (this.get('saving')) {
        return Em.String.i18n('saving');
      }
      return Em.String.i18n('topic.move_selected.title');
    }).property('saving'),
    movePosts: function() {
      var postIds,
        _this = this;
      this.set('saving', true);
      postIds = this.get('selectedPosts').map(function(p) {
        return p.get('id');
      });
      Discourse.Topic.movePosts(this.get('topic.id'), this.get('topicName'), postIds).then(function(result) {
        if (result.success) {
          jQuery('#discourse-modal').modal('hide');
          return Em.run.next(function() {
            return Discourse.routeTo(result.url);
          });
        } else {
          _this.flash(Em.String.i18n('topic.move_selected.error'));
          return _this.set('saving', false);
        }
      }, function() {
        _this.flash(Em.String.i18n('topic.move_selected.error'));
        return _this.set('saving', false);
      });
      return false;
    }
  });

}).call(this);
