# name: linkedin.com
# about: Authenticate with discourse with linkedin.com, see more at: https://developer.linkedin.com
# version: 0.1.0
# author: Jess Portnoy, Kaltura, Inc.

gem 'omniauth-linkedin', '0.2.0'

class LinkedInAuthenticator < ::Auth::Authenticator

  #CLIENT_ID = '77mp5lhgwm2iyq'
  #CLIENT_SECRET = '9h02a3QpcUKrQ88r'
  
CLIENT_ID = '77uvc5see6n043'
  CLIENT_SECRET = 'No0tuGoNN0AGDC0A'
  def name
    'linkedin'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    # grap the info we need from omni auth
    data = auth_token[:info]
    raw_info = auth_token["extra"]["raw_info"]
    name = data["name"]
    li_uid = auth_token["uid"]

    # plugin specific data storage
    current_info = ::PluginStore.get("li", "li_uid_#{li_uid}")

    result.user =
      if current_info
        User.where(id: current_info[:user_id]).first
      end

    result.name = name
    result.extra_data = { li_uid: li_uid }

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    ::PluginStore.set("li", "li_uid_#{data[:li_uid]}", {user_id: user.id })
  end

  def register_middleware(omniauth)
    omniauth.provider :linkedin,
     CLIENT_ID,
     CLIENT_SECRET
  end
end


auth_provider :title => 'with LinkedIn',
    :message => 'Log in via LinkedIn (Make sure pop up blockers are not enabled).',
    :frame_width => 920,
    :frame_height => 800,
    :authenticator => LinkedInAuthenticator.new


# We ship with zocial, it may have an icon you like http://zocial.smcllns.com/sample.html
#  in our current case we have an icon for li
register_css <<CSS

.btn-social.linkedin {
  background: #46698f;
}

.btn-social.linkedin:before {
  content: "L";
}

CSS
