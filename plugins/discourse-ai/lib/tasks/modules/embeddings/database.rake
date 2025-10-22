# frozen_string_literal: true

desc "Backfill embeddings for all topics and posts"
task "ai:embeddings:backfill", %i[embedding_def_id concurrency] => [:environment] do |_, args|
  public_categories = Category.where(read_restricted: false).pluck(:id)

  if args[:embedding_def_id].present?
    vdef = EmbeddingDefinition.find(args[:embedding_def_id])
    vector_rep = DiscourseAi::Embeddings::Vector.new(vdef)
  else
    vector_rep = DiscourseAi::Embeddings::Vector.instance
  end
  topics_table_name = DiscourseAi::Embeddings::Schema::TOPICS_TABLE

  topics =
    Topic
      .joins("LEFT JOIN #{topics_table_name} ON #{topics_table_name}.topic_id = topics.id")
      .where("#{topics_table_name}.topic_id IS NULL")
      .where("category_id IN (?)", public_categories)
      .where(deleted_at: nil)
      .order("topics.id DESC")

  Parallel.each(topics.all, in_processes: args[:concurrency].to_i, progress: "Topics") do |t|
    ActiveRecord::Base.connection_pool.with_connection do
      vector_rep.generate_representation_from(t)
    end
  end

  posts_table_name = DiscourseAi::Embeddings::Schema::POSTS_TABLE
  posts =
    Post
      .joins("LEFT JOIN #{posts_table_name} ON #{posts_table_name}.post_id = posts.id")
      .where("#{posts_table_name}.post_id IS NULL")
      .where(deleted_at: nil)
      .order("posts.id DESC")

  Parallel.each(posts.all, in_processes: args[:concurrency].to_i, progress: "Posts") do |t|
    ActiveRecord::Base.connection_pool.with_connection do
      vector_rep.generate_representation_from(t)
    end
  end
end
