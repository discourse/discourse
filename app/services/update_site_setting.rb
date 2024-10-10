# frozen_string_literal: true

class UpdateSiteSetting
  include Service::Base

  options do
    # to have syntax tree leave this as a block
    attribute :allow_changing_hidden, :boolean, default: false
  end

  policy :current_user_is_admin
  contract do
    attribute :setting_name
    attribute :new_value

    before_validation { self.setting_name = setting_name&.to_sym }

    validates :setting_name, presence: true
  end
  policy :setting_is_visible
  policy :setting_is_configurable
  step :cleanup_value
  step :save

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_visible(contract:, options:)
    options.allow_changing_hidden || !SiteSetting.hidden_settings.include?(contract.setting_name)
  end

  def setting_is_configurable(contract:)
    return true if !SiteSetting.plugins[contract.setting_name]

    Discourse.plugins_by_name[SiteSetting.plugins[contract.setting_name]].configurable?
  end

  def cleanup_value(contract:)
    new_value = contract.new_value
    new_value = new_value.strip if new_value.is_a?(String)

    case SiteSetting.type_supervisor.get_type(contract.setting_name)
    when :integer
      new_value = new_value.tr("^-0-9", "").to_i if new_value.is_a?(String)
    when :file_size_restriction
      new_value = new_value.tr("^0-9", "").to_i if new_value.is_a?(String)
    when :uploaded_image_list
      new_value = new_value.blank? ? "" : Upload.get_from_urls(new_value.split("|")).to_a
    when :upload
      new_value = Upload.get_from_url(new_value) || ""
    end
    context[:new_value] = new_value
  end

  def save(contract:, new_value:, guardian:)
    SiteSetting.set_and_log(contract.setting_name, new_value, guardian.user)
  end
end
