# frozen_string_literal: true

module PageObjects
  module Pages
    class Wizard < PageObjects::Pages::Base
      attr_reader :introduction_step, :privacy_step, :ready_step, :corporate_step

      def initialize
        @introduction_step = PageObjects::Pages::Wizard::IntroductionStep.new(self)
        @privacy_step = PageObjects::Pages::Wizard::PrivacyStep.new(self)
        @ready_step = PageObjects::Pages::Wizard::ReadyStep.new(self)
      end

      def go_to_step(step_id)
        visit("/wizard/steps/#{step_id}")
      end

      def on_step?(step_id)
        has_css?(".wizard-container__step.#{step_id}")
      end

      def click_jump_in
        find(".wizard-container__button.jump-in").click
      end

      def go_to_next_step
        find(".wizard-container__button.next").click
      end

      def find_field(field_type, field_id)
        find(".wizard-container__field.#{field_type}-field.#{field_type}-#{field_id}")
      end

      def fill_field(field_type, field_id, value)
        find_field(field_type, field_id).fill_in(with: value)
      end

      def select_dropdown_option(field_id, option_value)
        droppdown =
          PageObjects::Components::SelectKit.new(
            ".wizard-container__field.dropdown-#{field_id} .wizard-container__dropdown",
          )
        droppdown.expand
        droppdown.select_row_by_value(option_value)
        droppdown.collapse
      end

      def has_field_with_value?(field_type, field_id, value)
        find_field(field_type, field_id).find("input").value == value
      end
    end
  end
end

class PageObjects::Pages::Wizard::StepBase < PageObjects::Pages::Base
  attr_reader :wizard

  def initialize(wizard)
    @wizard = wizard
  end
end

class PageObjects::Pages::Wizard::IntroductionStep < PageObjects::Pages::Wizard::StepBase
end

class PageObjects::Pages::Wizard::PrivacyStep < PageObjects::Pages::Wizard::StepBase
  def choice_selector(choice_id)
    ".wizard-container__radio-choice[data-choice-id='#{choice_id}']"
  end

  def select_access_option(section, choice_id)
    wizard.find_field("radio", section).find(choice_selector(choice_id)).click
  end

  def has_selected_choice?(section, choice_id)
    wizard.find_field("radio", section).has_css?(choice_selector(choice_id) + ".--selected")
  end
end

class PageObjects::Pages::Wizard::ReadyStep < PageObjects::Pages::Wizard::StepBase
end
