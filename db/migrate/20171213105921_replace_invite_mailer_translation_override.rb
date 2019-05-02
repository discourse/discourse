# frozen_string_literal: true

class ReplaceInviteMailerTranslationOverride < ActiveRecord::Migration[5.1]
  def change
    execute <<~SQL
      UPDATE translation_overrides
      SET value = replace(value, '%{invitee_name}', '%{inviter_name}')
      WHERE translation_key IN ('invite_mailer.subject_template', 'invite_mailer.text_body_template',
                                'invite_forum_mailer.subject_template', 'invite_forum_mailer.text_body_template',
                                'custom_invite_mailer.subject_template', 'custom_invite_mailer.text_body_template',
                                'custom_invite_forum_mailer.subject_template', 'custom_invite_forum_mailer.text_body_template');
    SQL
  end
end
