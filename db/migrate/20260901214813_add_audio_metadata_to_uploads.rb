# frozen_string_literal: true

class AddAudioMetadataToUploads < ActiveRecord::Migration[8.0]
  def change
    add_column :uploads, :audio_duration_ms, :integer
    add_column :uploads, :audio_waveform, :binary
    add_column :uploads, :audio_waveform_version, :integer
  end
end
