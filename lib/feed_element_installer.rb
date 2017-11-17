require 'rexml/document'
require 'rss'

class FeedElementInstaller
  private_class_method :new

  def self.install(element_name, feed)
    # RSS Specification at http://cyber.harvard.edu/rss/rss.html#extendingRss
    # > A RSS feed may contain [non-standard elements], only if those elements are *defined in a namespace*

    new(element_name, feed).install if element_name.include?(':')
  end

  attr_reader :feed, :original_name, :element_namespace, :element_name, :element_accessor

  def initialize(element_name, feed)
    @feed = feed
    @original_name = element_name
    @element_namespace, @element_name = *element_name.split(':')
    @element_accessor = "#{@element_namespace}_#{@element_name}"
  end

  def element_uri
    @element_uri ||= REXML::Document.new(feed).root&.attributes&.namespaces&.fetch(@element_namespace, '') || ''
  end

  def install
    install_in_rss unless installed_in_rss?
    install_in_atom unless installed_in_atom?
  end

  private

  def install_in_rss
    RSS::Rss::Channel::Item.install_text_element(element_name, element_uri, '?', element_accessor, nil, original_name)
    RSS::BaseListener.install_get_text_element(element_uri, element_name, element_accessor)
  end

  def install_in_atom
    RSS::Atom::Entry.install_text_element(element_name, element_uri, '?', element_accessor, nil, original_name)
    RSS::Atom::Feed::Entry.install_text_element(element_name, element_uri, '?', element_accessor, nil, original_name)
    RSS::BaseListener.install_get_text_element(element_uri, element_name, element_accessor)
  end

  def installed_in_rss?
    RSS::Rss::Channel::Item.method_defined?(element_accessor)
  end

  def installed_in_atom?
    RSS::Atom::Entry.method_defined?(element_accessor) || RSS::Atom::Feed::Entry.method_defined?(element_accessor)
  end
end
