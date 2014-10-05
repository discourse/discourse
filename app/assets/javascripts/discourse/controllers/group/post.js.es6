export default Em.ObjectController.extend({

  byName: function() {
    var result = "",
        longName = this.get('user_long_name'),
        title = this.get('user_title');

    if (!Em.isEmpty(longName)) {
      result += longName;
    }
    if (!Em.isEmpty(title)) {
      if (result.length > 0) {
        result += ", ";
      }
      result += title;
    }
    return result;
  }.property()

});

