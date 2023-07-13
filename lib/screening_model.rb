# frozen_string_literal: true

module ScreeningModel
  extend ActiveSupport::Concern

  module ClassMethods
    def actions
      @actions ||= Enum.new(:block, :do_nothing, :allow_admin)
    end

    def default_action(action_key)
      @default_action = action_key
    end

    def df_action
      @default_action || :do_nothing
    end
  end

  included { before_validation :set_default_action }

  def set_default_action
    self.action_type ||= self.class.actions[self.class.df_action]
  end

  def action_name=(arg)
    if arg.nil? || !self.class.actions.has_key?(arg.to_sym)
      raise ArgumentError.new("Invalid action type #{arg}")
    end
    self.action_type = self.class.actions[arg.to_sym]
  end

  def record_match!
    self.match_count += 1
    self.last_match_at = Time.zone.now
    save
  end
end
