# frozen_string_literal: true

module PageObjects
  module Components
    class ReviewNoteForm < PageObjects::Components::Base
      def add_note(note)
        form.fill_in("note", with: note)
        form.submit
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".reviewable-note-form__form")
      end
    end
  end
end
