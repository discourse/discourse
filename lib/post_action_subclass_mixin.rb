
module PostActionSubclassMixin

  def self.included(cls)
    cls.extend PostActionSubclassMixin::ClassMethods
    cls.before_save :ensure_proper_type
  end

  module ClassMethods
    def pa_type=(type)
      @pa_type = type
    end

    def pa_type
      @pa_type
    end

    def sti_name
      pa_type
    end

    def type_condition(table = arel_table)
      table[:post_action_type_id].in([pa_type])
    end
  end

  def pa_type
    self.class.pa_type
  end

  def ensure_proper_type
    write_attribute(:post_action_type_id, pa_type)
  end
end
