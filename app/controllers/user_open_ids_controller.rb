require 'openid'
require 'openid/extensions/sreg'
require 'openid/extensions/ax'
require 'openid/store/filesystem'

require_dependency 'email'


class UserOpenIdsController < ApplicationController
  layout false

  # need to be able to call this
  skip_before_filter :check_xhr

  # must be done, cause we may trigger a POST
  skip_before_filter :verify_authenticity_token, :only => :complete

  def frame
    if params[:provider] == 'google'
      params[:user_open_id] = {url: "https://www.google.com/accounts/o8/id"}
    end
    if params[:provider] == 'yahoo'
      params[:user_open_id] = {url: "https://me.yahoo.com"}
    end
    create
  end

  def destroy
    @open_id = UserOpenId.find(params[:id])
    if @open_id.user.id == current_user.id
      @open_id.destroy
    end
    redirect_to current_user
  end

  def new
    @open_id = UserOpenId.new
  end

  def create
    url = params[:user_open_id]

    begin
      # validations
      @open_id = UserOpenId.new(url)
      open_id_request = openid_consumer.begin @open_id.url
      return_to, realm = ['complete','index'].map {|a| url_for :action => a, :only_path => false}

      add_ax_request(open_id_request)
      add_sreg_request(open_id_request)

      # immediate mode is not required
      if open_id_request.send_redirect?(realm, return_to, false)
        redirect_to open_id_request.redirect_url(realm, return_to, false)
      else
        logger.warn("send_redirect? returned false")
        render :text, open_id_request.html_markup(realm, return_to, false, {'id' => 'openid_form'})
      end
    rescue => e
      flash[:error] = "There seems to be something wrong with your open id url"
      logger.warn("failed to load contact open id: " + e.to_s)
      render :text => 'Something went wrong, we have been notified, try again soon'
    end
  end

  def complete
    current_url = url_for(:action => 'complete', :only_path => false)
    parameters = params.reject{|k,v|request.path_parameters[k]}.reject{|k,v| k == 'action' || k == 'controller'}
    open_id_response = openid_consumer.complete(parameters, current_url)

    case open_id_response.status
    when OpenID::Consumer::SUCCESS
      data = {}
      if params[:did_sreg]
        data = get_sreg_response(open_id_response)
      end

      if params[:did_ax]
        info = get_ax_response(open_id_response)
        data.merge!(info)
      end

      trusted = open_id_response.endpoint.server_url =~ /\Ahttps:\/\/www\.google\.com\// ||
        open_id_response.endpoint.server_url =~ /\Ahttps:\/\/me\.yahoo\.com\//

      email = data[:email]
      user_open_id = UserOpenId.where(url: open_id_response.display_identifier).first

      if trusted && user_open_id.nil? && user = User.where(email: email).first
        # we trust so do an email lookup
        user_open_id = UserOpenId.create(url: open_id_response.display_identifier, user_id: user.id, email: email, active: true)
      end

      authenticated = !user_open_id.nil?

      if authenticated
        user = user_open_id.user

        # If we have to approve users
        if SiteSetting.must_approve_users? and !user.approved?
          @data = {awaiting_approval: true}
        else
          log_on_user(user)
          @data = {authenticated: true}
        end

      else
        @data = {
          email: email,
          name: User.suggest_name(email),
          username: User.suggest_username(email),
          email_valid: trusted,
          auth_provider: "Google"
        }
        session[:authentication] = {
          email: @data[:email],
          email_valid: @data[:email_valid],
          openid_url: open_id_response.display_identifier
        }
      end

    else
      # note there are lots of failure reasons, we treat them all as failures
      logger.warn("Verification #{open_id_response.display_identifier || "" }"\
                  " failed: #{open_id_response.status.to_s}" )
      logger.warn(open_id_response.message)
      flash[:error] = "Sorry, I seem to be having trouble confirming your open id account, please try again!"
      render :text => "Apologies, something went wrong ... try again soon"
    end
  end


  protected


  def persist_session
    if s = UserSession.find
      s.remember_me = true
      s.save
    end
  end

  def openid_consumer
    @openid_consumer ||= OpenID::Consumer.new(session,
      OpenID::Store::Filesystem.new("#{Rails.root}/tmp/openid"))
  end

  def get_sreg_response(open_id_response)
    data = {}
    sreg_resp = OpenID::SReg::Response.from_success_response(open_id_response)
    unless sreg_resp.empty?
      data[:email] = sreg_resp.data['email']
      data[:nickname] = sreg_resp.data['nickname']
    end
    data
  end

  def get_ax_response(open_id_response)
    data = {}
    ax_resp = OpenID::AX::FetchResponse.from_success_response(open_id_response)
    if ax_resp && !ax_resp.data.empty?
      data[:email] = ax_resp.data['http://schema.openid.net/contact/email'][0]
    end
    data
  end

  def add_sreg_request(open_id_request)
    sreg_request = OpenID::SReg::Request.new
    sreg_request.request_fields(['email'], true)
    # optional
    sreg_request.request_fields(['dob', 'fullname', 'nickname'], false)
    open_id_request.add_extension(sreg_request)
    open_id_request.return_to_args['did_sreg'] = 'y'

  end

  def add_ax_request(open_id_request)
    ax_request = OpenID::AX::FetchRequest.new
    requested_attrs = [
                  ['namePerson', 'fullname'],
                  ['namePerson/friendly', 'nickname'],
                  ['contact/email', 'email', true],
                  ['contact/web/default', 'web_default'],
                  ['birthDate', 'dob'],
                  ['contact/country/home', 'country']
    ]

    requested_attrs.each {|a| ax_request.add(OpenID::AX::AttrInfo.new("http://schema.openid.net/#{a[0]}", a[1], a[2] || false))}
    open_id_request.add_extension(ax_request)
    open_id_request.return_to_args['did_ax'] = 'y'
  end
end
