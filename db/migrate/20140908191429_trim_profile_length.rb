class TrimProfileLength < ActiveRecord::Migration
  def change
    # In case any profiles exceed 3000 chars
    execute "UPDATE user_profiles SET bio_raw=LEFT(bio_raw, 3000)"
  end
end
