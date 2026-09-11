# frozen_string_literal: true

class ProblemCheck::AuthProviderConfig < ProblemCheck
  def call
    return no_problem if !SiteSetting.get(authenticator.enable_setting)
    return no_problem if authenticator.configured?

    problem
  end

  private

  def authenticator
    raise NotImplementedError
  end

  def translation_data
    {
      missing_settings:
        SiteSettings::LabelFormatter.setting_markers(authenticator.missing_settings),
    }
  end
end
