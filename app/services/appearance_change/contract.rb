# frozen_string_literal: true

# Parameters shared by the services that save appearance changes: a name and
# the fonts to use once the change is live.
class AppearanceChange::Contract < Service::ContractBase
  attribute :name, :string
  attribute :site_settings, :hash, default: -> { {} } do
    attribute :base_font, :string
    attribute :heading_font, :string

    validates :base_font,
              :heading_font,
              inclusion: {
                in: BaseFontSetting.values.map { |font| font[:value] },
              },
              allow_blank: true
  end

  validates :name, presence: true, length: { maximum: 100 }

  def site_settings_to_apply
    (site_settings&.to_hash || {}).compact_blank.stringify_keys
  end
end
