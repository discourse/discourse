# frozen_string_literal: true

class DiscourseSolved::AcceptedAnswerSerializer < PostExcerptAccordionItemSerializer
  def include_cooked?
    SiteSetting.solved_quote_length > 0
  end
end
