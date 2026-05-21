# frozen_string_literal: true

class DiscourseSolved::AcceptedAnswerSerializer < PostAccordionItemSerializer
  attributes :accepter_name, :accepter_username

  def name
    object.user&.name || Discourse.system_user.name
  end

  def username
    object.user&.username || Discourse.system_user.username
  end

  def avatar_template
    object.user&.avatar_template || Discourse.system_user.avatar_template
  end

  def accepter_name
    @options[:accepter]&.name || object.topic&.user&.name || Discourse.system_user.name
  end

  def accepter_username
    @options[:accepter]&.username || object.topic&.user&.username || Discourse.system_user.username
  end

  def include_accepter_name?
    SiteSetting.show_who_marked_solved && SiteSetting.enable_names? &&
      SiteSetting.display_name_on_posts
  end

  def include_accepter_username?
    SiteSetting.show_who_marked_solved
  end

  def include_cooked?
    SiteSetting.solved_quote_length > 0
  end

  def include_name?
    SiteSetting.enable_names? && SiteSetting.display_name_on_posts
  end
end
