# frozen_string_literal: true

module DiscourseAutomation
  class EntryPoint
    def self.inject(plugin)
      plugin.on(:accepted_solution) do |post|
        # testing directly automation is prone to issues
        # we prefer to abstract logic in service object and test this
        next if Rails.env.test?

        name = "first_accepted_solution"
        DiscourseAutomation::Automation
          .where(trigger: name, enabled: true)
          .find_each do |automation|
            maximum_trust_level = automation.trigger_field("maximum_trust_level")&.dig("value")
            if DiscourseSolved::FirstAcceptedPostSolutionValidator.check(
                 post,
                 trust_level: maximum_trust_level,
               )
              automation.trigger!(
                "kind" => name,
                "accepted_post_id" => post.id,
                "usernames" => [post.user.username],
                "placeholders" => {
                  "post_url" => Discourse.base_url + post.url,
                },
              )
            end
          end
      end

      plugin.add_triggerable_to_scriptable(:first_accepted_solution, :send_pms)

      DiscourseAutomation::Triggerable.add(:first_accepted_solution) do
        placeholder :post_url

        field :maximum_trust_level,
              component: :choices,
              extra: {
                content: [
                  {
                    id: 1,
                    name:
                      "discourse_automation.triggerables.first_accepted_solution.max_trust_level.tl1",
                  },
                  {
                    id: 2,
                    name:
                      "discourse_automation.triggerables.first_accepted_solution.max_trust_level.tl2",
                  },
                  {
                    id: 3,
                    name:
                      "discourse_automation.triggerables.first_accepted_solution.max_trust_level.tl3",
                  },
                  {
                    id: 4,
                    name:
                      "discourse_automation.triggerables.first_accepted_solution.max_trust_level.tl4",
                  },
                  {
                    id: "any",
                    name:
                      "discourse_automation.triggerables.first_accepted_solution.max_trust_level.any",
                  },
                ],
              },
              required: true
      end
    end
  end
end
