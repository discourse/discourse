# frozen_string_literal: true

class TagSettingsUpdater
  attr_reader :tag, :errors

  def initialize(tag, actor)
    @tag = tag
    @actor = actor
    @errors = []
  end

  def self.update(tag, actor, params)
    new(tag, actor).update(params)
  end

  def update(params)
    old_tag_name = @tag.name

    Tag.transaction do
      update_basic_attributes(params)

      unless @tag.save
        @errors = @tag.errors.full_messages
        raise ActiveRecord::Rollback
      end

      log_rename(old_tag_name) if @tag.name != old_tag_name
      remove_synonyms(params[:removed_synonym_ids])
      add_synonyms(params[:new_synonyms])
      update_localizations(params[:localizations])
    end

    @errors.empty?
  end

  def updated_tag
    Tag.includes(:synonyms, :localizations, :tag_groups).find(@tag.id)
  end

  private

  def update_basic_attributes(params)
    @tag.name = DiscourseTagging.clean_tag(params[:name]) if params[:name].present?
    @tag.slug = params[:slug] if params[:slug].present?
    @tag.description = params[:description] if params.key?(:description)
  end

  def log_rename(old_name)
    StaffActionLogger.new(@actor).log_custom(
      "renamed_tag",
      previous_value: old_name,
      new_value: @tag.name,
    )
  end

  def remove_synonyms(removed_ids)
    return if removed_ids.blank?

    Tag.where(id: removed_ids, target_tag_id: @tag.id).update_all(target_tag_id: nil)
  end

  def add_synonyms(new_synonyms)
    return if new_synonyms.blank?

    synonym_tag_ids = new_synonyms.filter_map { |t| t[:id]&.to_i }
    DiscourseTagging.add_or_create_synonyms(@tag, synonym_tag_ids:) if synonym_tag_ids.present?
  end

  def update_localizations(localizations)
    return if localizations.blank?

    submitted_locales = []

    localizations.each do |loc|
      locale = loc[:locale]
      next if locale.blank?

      submitted_locales << locale

      existing = TagLocalization.find_by(tag_id: @tag.id, locale: locale)
      if existing
        existing.update!(name: loc[:name], description: loc[:description])
      else
        TagLocalization.create!(
          tag_id: @tag.id,
          locale: locale,
          name: loc[:name],
          description: loc[:description],
        )
      end
    end

    TagLocalization.where(tag_id: @tag.id).where.not(locale: submitted_locales).delete_all
  end
end
