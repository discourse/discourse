class WebHookPostSerializer < PostSerializer
  def include_can_edit?
    false
  end

  def can_delete
    false
  end

  def can_recover
    false
  end

  def can_wiki
    false
  end
end
