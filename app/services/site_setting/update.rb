# frozen_string_literal: true

class SiteSetting::Update
  include Service::Base

  policy :current_user_is_admin
  contract do
    attribute :setting_name
    attribute :new_value
    attribute :allow_changing_hidden, :boolean, default: false

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

  def setting_is_visible(contract:)
    contract.allow_changing_hidden || !SiteSetting.hidden_settings.include?(contract.setting_name)
  end

  def setting_is_configurable(contract:)
    return true if !SiteSetting.plugins[contract.setting_name]

    Discourse.plugins_by_name[SiteSetting.plugins[contract.setting_name]].configurable?
  end

  def save(contract:, guardian:)
    SiteSetting.set_and_log(contract.setting_name, contract.new_value, guardian.user)
  end
end
