module Jobs
  class RecoverUserProfileBackgrounds < Jobs::Onceoff
    def execute_onceoff(_)
      base_url = Discourse.store.absolute_base_url
      return if !base_url.match?(/s3\.dualstack/)

      old = base_url.sub('s3.dualstack.', 's3-')
      old_like = %"#{old}%"

      DB.exec(<<~SQL, from: old, to: base_url, old_like: old_like)
        UPDATE user_profiles
        SET profile_background = replace(profile_background, :from, :to)
        WHERE profile_background ilike :old_like
      SQL

      DB.exec(<<~SQL, from: old, to: base_url, old_like: old_like)
        UPDATE user_profiles
        SET card_background = replace(card_background, :from, :to)
        WHERE card_background ilike :old_like
      SQL

      UploadRecovery.new.recover_user_profile_backgrounds
    end
  end
end
