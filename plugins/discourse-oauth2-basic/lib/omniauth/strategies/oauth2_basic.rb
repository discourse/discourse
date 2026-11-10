# frozen_string_literal: true

class OmniAuth::Strategies::Oauth2Basic < ::OmniAuth::Strategies::OAuth2
  option :name, "oauth2_basic"

  uid do
    if path = SiteSetting.oauth2_callback_user_id_path.split(".")
      recurse(access_token, [*path]) if path.present?
    end
  end

  info do
    if paths = SiteSetting.oauth2_callback_user_info_paths.split("|")
      result = Hash.new
      paths.each do |p|
        segments = p.split(":")
        if segments.length == 2
          key = segments.first
          path = [*segments.last.split(".")]
          result[key] = recurse(access_token, path)
        end
      end
      result
    end
  end

  def callback_url
    Discourse.base_url_no_prefix + script_name + callback_path
  end

  def recurse(obj, keys)
    return nil if !obj
    k = keys.shift
    # Configured paths may only traverse response data, never invoke Ruby methods.
    result =
      if obj.is_a?(::OAuth2::AccessToken)
        k == "params" ? obj.params : obj[k]
      elsif obj.is_a?(Hash)
        obj[k]
      end
    keys.empty? ? result : recurse(result, keys)
  end
end
