class UserOptionSerializer < ApplicationSerializer
  attributes :user_id,
             :email_always,
             :mailing_list_mode,
             :email_digests,
             :email_private_messages,
             :email_direct,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :enable_quoting,
             :disable_jump_reply,
             :digest_after_days,
             :automatically_unpin_topics,
             :edit_history_public


  def include_edit_history_public?
    !SiteSetting.edit_history_visible_to_public
  end
end
