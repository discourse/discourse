# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class AddReviewableNote < Tool
        def self.signature
          {
            name: name,
            description:
              "Adds a note to a review queue item without changing its status. Use this to record an assessment or judgment about a reviewable so human moderators can see it. Use list_reviewables first to find items and their existing notes.",
            parameters: [
              {
                name: "reviewable_id",
                description: "The ID of the reviewable item to add a note to",
                type: "integer",
                required: true,
              },
              {
                name: "note",
                description: "The note content to add to the reviewable item",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "add_reviewable_note"
        end

        def self.requires_approval?
          false
        end

        def invoke
          if !guardian.can_see_review_queue?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.add_reviewable_note.errors.not_allowed"))
            )
          end

          if note_content.blank?
            return(error_response(I18n.t("discourse_ai.ai_bot.add_reviewable_note.errors.no_note")))
          end

          reviewable = Reviewable.viewable_by(guardian.user).find_by(id: parameters[:reviewable_id])
          if !reviewable
            return(
              error_response(I18n.t("discourse_ai.ai_bot.add_reviewable_note.errors.not_found"))
            )
          end

          note = reviewable.reviewable_notes.build(content: note_content, user: acting_user)

          if note.save
            {
              status: "success",
              message:
                I18n.t(
                  "discourse_ai.ai_bot.add_reviewable_note.success",
                  reviewable_id: reviewable.id,
                ),
              note_id: note.id,
            }
          else
            error_response(
              note.errors.full_messages.join(", ").presence ||
                I18n.t("discourse_ai.ai_bot.add_reviewable_note.errors.failed"),
            )
          end
        end

        def description_args
          { reviewable_id: parameters[:reviewable_id] }
        end

        private

        def note_content
          parameters[:note].to_s.strip
        end
      end
    end
  end
end
