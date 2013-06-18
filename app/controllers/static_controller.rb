class StaticController < ApplicationController

  skip_before_filter :check_xhr, :redirect_to_login_if_required

  def show

    page = params[:id]

    return redirect_to(SiteSetting.tos_url) if page == 'tos' and !SiteSetting.tos_url.blank?
    return redirect_to(SiteSetting.privacy_policy_url) if page == 'privacy' and !SiteSetting.privacy_policy_url.blank?

    # Don't allow paths like ".." or "/" or anything hacky like that
    page.gsub!(/[^a-z0-9\_\-]/, '')

    file = "static/#{page}.#{I18n.locale}"

    # if we don't have a localized version, try the English one
    if not lookup_context.find_all("#{file}.html").any?
      file = "static/#{page}.en"
    end

    if lookup_context.find_all("#{file}.html").any?
      render file, layout: !request.xhr?, formats: [:html]
      return
    end

    raise Discourse::NotFound
  end

  # This method just redirects to a given url.
  # It's used when an ajax login was successful but we want the browser to see
  # a post of a login form so that it offers to remember your password.
  def enter
    params.delete(:username)
    params.delete(:password)

    redirect_to(
      if params[:redirect].blank? || params[:redirect].match(login_path)
        root_path
      else
        params[:redirect]
      end
    )
  end
end
