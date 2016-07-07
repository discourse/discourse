class WebHooksPostSerializer < PostSerializer
  def include_yours?
    false
  end

  def include_can_edit?
    false
  end

  def include_can_delete?
    false
  end

  def include_can_recover?
    false
  end

  def include_can_wiki?
    false
  end
end
