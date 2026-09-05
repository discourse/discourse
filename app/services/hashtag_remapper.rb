# frozen_string_literal: true

class HashtagRemapper
  DEFAULT_CONTEXT = "topic-composer"

  def self.stores
    [
      PostStore,
      PostLocalizationStore,
      UserProfileStore,
      GroupStore,
      TagDescriptionStore,
      TagLocalizationStore,
      SiteSettingLocalizationStore,
      CategoryLocalizationStore,
    ] | DiscoursePluginRegistry.hashtag_content_stores.to_a
  end

  def self.enqueue(remaps)
    usable =
      remaps.reject do |remap|
        current = HashtagAutocompleteService.ref_for(remap[:type], remap[:id])
        current.present? && remap[:old_ref].casecmp?(current)
      end
    return if usable.blank?

    DB.after_commit { Jobs.enqueue(:remap_hashtag, remaps: usable) }
  end

  def self.remap!(type:, id:, old_ref:, rewritten: Set.new)
    return if type.blank? || id.blank? || !HashtagRewriter.usable_ref?(old_ref)

    new_ref = HashtagAutocompleteService.ref_for(type, id)
    return if new_ref.blank? || old_ref.casecmp?(new_ref)
    return if !HashtagRewriter.usable_ref?(new_ref)

    new(type:, record_id: id, old_ref:, new_ref:, rewritten:).remap!
  end

  def initialize(type:, record_id:, old_ref:, new_ref:, rewritten: Set.new)
    @type = type
    @record_id = record_id.to_s
    @old_ref = old_ref
    @new_ref = new_ref
    @old_suffixed = "#{old_ref}::#{type}"
    @new_suffixed = "#{new_ref}::#{type}"
    @rewritten = rewritten
    @bare_new_refs = {}
  end

  def remap!
    self
      .class
      .stores
      .to_h { |store| [store.key, remap_store(store)] }
      .reject { |_, counts| counts.empty? }
  end

  private

  attr_reader :type, :record_id, :old_ref, :new_ref, :old_suffixed, :new_suffixed, :rewritten

  def remap_store(store)
    counts = Hash.new(0)

    store
      .candidates(old_ref)
      .find_each do |record|
        counts[:scanned] += 1
        counts[:rewritten] += 1 if rewrite_record(store, record)
      rescue => error
        counts[:failed] += 1
        Discourse.warn_exception(
          error,
          message:
            "Failed to remap #{type} hashtag ##{old_ref} to ##{new_ref} in #{store.key} #{record.id}",
        )
      end

    counts
  end

  def rewrite_record(store, record)
    raw = store.raw(record)
    return false if raw.blank?

    rewrite_bare = bare_ref_belongs_to_record?(store, record)

    new_raw =
      HashtagRewriter
        .new(raw, store.cook_options(record))
        .rewrite do |ref|
          next new_suffixed if ref.casecmp?(old_suffixed)
          next bare_new_ref(store) if rewrite_bare && ref.casecmp?(old_ref)
        end

    return false if new_raw == raw

    store.write!(record, new_raw)
    rewritten << [store, record.id]
    true
  end

  def bare_ref_belongs_to_record?(store, record)
    claims =
      PrettyText
        .extract_hashtags(store.cooked(record))
        .select { |anchor| anchor[:ref]&.casecmp?(old_ref) }

    return rewritten.include?([store, record.id]) if claims.empty?

    claims.all? { |anchor| points_at_record?(anchor) }
  end

  def bare_new_ref(store)
    context = store.hashtag_context || DEFAULT_CONTEXT

    @bare_new_refs[context] ||= begin
      found =
        PrettyText::Helpers.hashtag_lookup(
          new_ref,
          Discourse.system_user.id,
          HashtagAutocompleteService.ordered_types_for_context(context),
        )

      found && points_at_record?(found) ? new_ref : new_suffixed
    end
  end

  def points_at_record?(anchor)
    anchor[:type] == type && anchor[:id].to_s == record_id
  end
end
