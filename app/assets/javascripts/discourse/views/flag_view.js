(function() {

  window.Discourse.FlagView = Discourse.ModalBodyView.extend({
    templateName: 'flag',
    title: Em.String.i18n('flagging.title'),
    changePostActionType: function(action) {
      if (this.get('postActionTypeId') === action.id) {
        return false;
      }
      this.set('postActionTypeId', action.id);
      this.set('isCustomFlag', action.is_custom_flag);
      Em.run.next(function() {
        return jQuery("#radio_" + action.name_key).prop('checked', 'true');
      });
      return false;
    },
    createFlag: function() {
      var actionType, _ref,
        _this = this;
      actionType = Discourse.get("site").postActionTypeById(this.get('postActionTypeId'));
      if (_ref = this.get("post.actionByName." + (actionType.get('name_key')))) {
        _ref.act({
          message: this.get('customFlagMessage')
        }).then(function() {
          return jQuery('#discourse-modal').modal('hide');
        }, function(errors) {
          return _this.displayErrors(errors);
        });
      }
      return false;
    },
    customPlaceholder: (function() {
      return Em.String.i18n("flagging.custom_placeholder");
    }).property(),
    showSubmit: (function() {
      var m;
      if (this.get("postActionTypeId")) {
        if (this.get("isCustomFlag")) {
          m = this.get("customFlagMessage");
          return m && m.length >= 10 && m.length <= 500;
        } else {
          return true;
        }
      }
      return false;
    }).property("isCustomFlag", "customFlagMessage", "postActionTypeId"),
    customFlagMessageChanged: (function() {
      var len, message, minLen, _ref;
      minLen = 10;
      len = ((_ref = this.get('customFlagMessage')) ? _ref.length : void 0) || 0;
      this.set("customMessageLengthClasses", "too-short custom-message-length");
      if (len === 0) {
        message = Em.String.i18n("flagging.custom_message.at_least", {
          n: minLen
        });
      } else if (len < minLen) {
        message = Em.String.i18n("flagging.custom_message.more", {
          n: minLen - len
        });
      } else {
        message = Em.String.i18n("flagging.custom_message.left", {
          n: 500 - len
        });
        this.set("customMessageLengthClasses", "ok custom-message-length");
      }
      this.set("customMessageLength", message);
    }).observes("customFlagMessage"),
    didInsertElement: function() {
      var $flagModal;
      this.customFlagMessageChanged();
      this.set('postActionTypeId', null);
      $flagModal = jQuery('#flag-modal');
      /* Would be nice if there were an EmberJs radio button to do this for us. Oh well, one should be coming
      */

      /* in an upcoming release.
      */

      jQuery("input[type='radio']", $flagModal).prop('checked', false);
    }
  });

}).call(this);
