window.Discourse.UserAction = Discourse.Model.extend
  postUrl:(->
    Discourse.Utilities.postUrl(@get('slug'), @get('topic_id'), @get('post_number'))
  ).property()
