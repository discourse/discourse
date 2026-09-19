# frozen_string_literal: true

class CustomEmoji::Export
  include Service::Base

  params do
    attribute :names, :array

    validates :names, presence: true

    before_validation { self.names = names.to_a.map(&:to_s).reject(&:blank?) }
  end

  model :emojis
  model :archive, :build_archive

  private

  def fetch_emojis(params:)
    CustomEmoji.where(name: params.names).includes(:upload)
  end

  def build_archive(emojis:)
    CustomEmoji::Action::BuildExportArchive.call(emojis:)
  end
end
