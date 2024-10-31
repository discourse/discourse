# frozen_string_literal: true

class SiteSetting::Update
  include Service::Base

  options { attribute :allow_changing_hidden, :boolean, default: false }

  policy :current_user_is_admin
  params do
    attribute :setting_name
    attribute :new_value

    before_validation do
      self.setting_name = setting_name&.to_sym
      self.new_value = new_value.to_s.strip
    end

    validates :setting_name, presence: true

    after_validation do
      next if setting_name.blank?
      self.new_value =
        case SiteSetting.type_supervisor.get_type(setting_name)
        when :integer
          new_value.tr("^-0-9", "").to_i
        when :file_size_restriction
          new_value.tr("^0-9", "").to_i
        when :uploaded_image_list
          new_value.blank? ? "" : Upload.get_from_urls(new_value.split("|")).to_a
        when :upload
          Upload.get_from_url(new_value) || ""
        else
          new_value
        end
    end
  end
  policy :setting_is_visible
  policy :setting_is_configurable
  step :save

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_visible(params:, options:)
    options.allow_changing_hidden || !SiteSetting.hidden_settings.include?(params.setting_name)
  end

  def setting_is_configurable(params:)
    return true if !SiteSetting.plugins[params.setting_name]

    Discourse.plugins_by_name[SiteSetting.plugins[params.setting_name]].configurable?
  end

  def save(params:, guardian:)
    SiteSetting.set_and_log(params.setting_name, params.new_value, guardian.user)
  end
end
