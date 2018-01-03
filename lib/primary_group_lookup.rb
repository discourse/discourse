class PrimaryGroupLookup
  def initialize(user_ids = [])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup primary group for a given user id
  def [](user_id)
    users[user_id]
  end

  private

  def self.lookup_columns
    @lookup_columns ||= %i{id name flair_url flair_bg_color flair_color}
  end

  def users
    @users ||= user_lookup_hash
  end

  def user_lookup_hash
    users_with_primary_group = User.where(id: @user_ids)
      .where.not(primary_group_id: nil)
      .select(:id, :primary_group_id)

    group_lookup = {}
    group_ids = users_with_primary_group.map(&:primary_group_id)
    group_ids.uniq!

    Group.where(id: group_ids).select(self.class.lookup_columns)
      .each { |g| group_lookup[g.id] = g }

    hash = {}
    users_with_primary_group.each do |u|
      hash[u.id] = group_lookup[u.primary_group_id]
    end
    hash
  end
end
