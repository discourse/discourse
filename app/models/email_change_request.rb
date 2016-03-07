class EmailChangeRequest < ActiveRecord::Base
  belongs_to :old_email_token, class_name: 'EmailToken'
  belongs_to :new_email_token, class_name: 'EmailToken'

  def self.states
    @states ||= Enum.new(authorizing_old: 1, authorizing_new: 2, complete: 3)
  end

end
