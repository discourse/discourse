# frozen_string_literal: true

class DiscourseSolved::AcceptedAnswerSerializer < PostAccordionItemSerializer
  attributes :accepter_name, :accepter_username

  def answer_user
    @answer_user ||= object.user || Discourse.system_user
  end

  def accepter_user
    @accepter_user ||= @options[:accepter] || object.topic&.user || Discourse.system_user
  end

  def name
    answer_user.name
  end

  def username
    answer_user.username
  end

  def avatar_template
    answer_user.avatar_template
  end

  def accepter_name
    accepter_user.name
  end

  def accepter_username
    accepter_user.username
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
