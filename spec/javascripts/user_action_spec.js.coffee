describe "Discourse.UserAction", ->

  describe "collapseStream", ->
    it "collapses all likes", ->
      actions = [
        Discourse.UserAction.create(action_type: Discourse.UserAction.LIKE, topic_id:1, user_id:1, post_number:1)
        Discourse.UserAction.create(action_type: Discourse.UserAction.EDIT, topic_id:2, user_id:1, post_number:1)
        Discourse.UserAction.create(action_type: Discourse.UserAction.LIKE, topic_id:1, user_id:2, post_number:1)
      ]

      actions = Discourse.UserAction.collapseStream(actions)
      expect(actions.length).toBe(2)

      expect(actions[0].get("children").length).toBe(1)
      expect(actions[0].get("children")[0].items.length).toBe(2)

