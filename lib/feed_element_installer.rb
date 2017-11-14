require 'rss'

module FeedElementInstaller
  module_function

  def install_rss_element(element_name)
    return if RSS::Rss::Channel::Item.method_defined?(element_name)

    RSS::Rss::Channel::Item.install_text_element(element_name, '', '?', element_name)
    RSS::BaseListener.install_get_text_element("", element_name, element_name)
  end

  def install_atom_element(element_name)
    return if RSS::Atom::Entry.method_defined?(element_name) ||
              RSS::Atom::Feed::Entry.method_defined?(element_name)

    RSS::Atom::Entry.install_text_element(element_name, '', '?', element_name)
    RSS::Atom::Feed::Entry.install_text_element(element_name, '', '?', element_name)
    RSS::BaseListener.install_get_text_element(RSS::Atom::URI, element_name, element_name)
  end
end
