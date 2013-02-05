class PostActionType < ActiveRecord::Base
  attr_accessible :id, :is_flag, :name_key, :icon

  def self.ordered
    self.order('position asc').all
  end

  def self.Types
    @types ||= {:bookmark => 1,
     :like => 2,
     :off_topic => 3,
     :inappropriate => 4,
     :vote => 5, 
     :custom_flag => 6,
     :spam => 8
    }    
  end

  def self.is_flag?(sym)
    self.FlagTypes.include?(self.Types[sym])
  end

  def self.AutoActionFlagTypes
    @auto_action_flag_types ||= [self.Types[:off_topic], self.Types[:spam], self.Types[:inappropriate]]
  end

  def self.FlagTypes
    @flag_types ||= self.AutoActionFlagTypes + [self.Types[:custom_flag]]
  end

end
