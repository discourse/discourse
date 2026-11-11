# frozen_string_literal: true

class QuoteComparer
  def self.whitespace
    " \t\r\n"
  end

  def initialize(topic_id, post_number, text, user: nil)
    @topic_id = topic_id
    @post_number = post_number
    @text = text
    @user = user
    @parent_post = visible_parent_post
  end

  # This algorithm is far from perfect, but it follows the Discourse
  # philosophy of "catch the obvious cases, leave moderation for the
  # complicated ones"
  def missing?
    @parent_post.blank?
  end

  def modified?
    return true if @text.blank?

    if @parent_post
      parent_text =
        Nokogiri::HTML5.fragment(@parent_post.cooked).text.delete(QuoteComparer.whitespace)
      text = @text.delete(QuoteComparer.whitespace)

      !parent_text.include?(text)
    end
  end

  private

  # Posts the quoting user cannot see (private messages, restricted
  # categories, deleted posts) are treated as missing. Otherwise the
  # quote-modified and quote-post-not-found markers baked into the cooked
  # HTML would let a user probe the existence and contents of posts they
  # do not have access to.
  def visible_parent_post
    parent_post = Post.where(topic_id: @topic_id, post_number: @post_number).first
    return if parent_post.blank? || @user.blank?
    return if !Guardian.new(@user).can_see?(parent_post)
    parent_post
  end
end
