# A nice object to help keep track of invited users
class InvitedList

  attr_accessor :pending
  attr_accessor :redeemed
  attr_accessor :by_user

  def initialize(user)
    @pending = []
    @redeemed = []
    @by_user = user

    invited = Invite.where(invited_by_id: @by_user.id)
                    .includes(:user => :user_stat)
                    .order(:redeemed_at)
    invited.each do |i|
      if i.redeemed?
        @redeemed << i
      else
        @pending << i unless i.expired?
      end
    end
  end

end
