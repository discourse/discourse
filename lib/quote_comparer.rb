class QuoteComparer
  def self.whitespace
    " \t\r\n".freeze
  end

  def initialize(topic_id, post_number, text)
    @topic_id = topic_id
    @post_number = post_number
    @text = text
    @parent_post = Post.where(topic_id: @topic_id, post_number: @post_number).first
  end

  # This algorithm is far from perfect, but it follows the Discourse
  # philosophy of "catch the obvious cases, leave moderation for the
  # complicated ones"
  def modified?
    return true if @text.blank? || @parent_post.blank?

    parent_text = Nokogiri::HTML::fragment(@parent_post.cooked).text.delete(QuoteComparer.whitespace)
    text = @text.delete(QuoteComparer.whitespace)

    !parent_text.include?(text)
  end
end
