module Jobs

  class MigrateFeaturedLinks < Jobs::Onceoff

    def execute_onceoff(args)
      TopicCustomField.where(name: "featured_link").find_each do |tcf|
        if tcf.value.present?
          Topic.where(id: tcf.topic_id).update_all(featured_link: tcf.value)
        end
      end

      # Plugin behaviour: only categories explicitly allowed to have featured links can have them.
      # All others implicitly DO NOT allow them.
      # If no categories were explicitly allowed to have them, then all implicitly DID allow them.

      allowed = CategoryCustomField.where(name: "topic_featured_link_allowed").where(value: "true").pluck(:category_id)

      if !allowed.empty?
        # all others are not allowed
        Category.where.not(id: allowed).update_all(topic_featured_link_allowed: false)
      else
        not_allowed = CategoryCustomField.where(name: "topic_featured_link_allowed").where.not(value: "true").pluck(:category_id)
        Category.where(id: not_allowed).update_all(topic_featured_link_allowed: false)
      end
    end
  end

end
