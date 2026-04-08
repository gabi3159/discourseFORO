# frozen_string_literal: true

class ExcludeSmallActionPostsFromTopicStats < ActiveRecord::Migration[8.0]
  # Small action posts (post_type = 3) were previously included in topic stats
  # for non-PM topics. This migration recalculates stats to exclude them,
  # matching the behavior that already existed for private messages.
  def up
    # Recalculate topic stats excluding small action posts (post_type 3)
    # and whispers (post_type 4) from highest_post_number, posts_count,
    # last_posted_at, last_post_user_id, and word_count.
    execute <<~SQL
      WITH
      visible_stats AS (
        SELECT topic_id,
               COALESCE(MAX(post_number), 0) AS highest_post_number,
               COUNT(*) AS posts_count,
               MAX(created_at) AS last_posted_at,
               SUM(COALESCE(word_count, 0)) AS word_count
        FROM posts
        WHERE deleted_at IS NULL AND post_type NOT IN (3, 4)
        GROUP BY topic_id
      ),
      last_poster AS (
        SELECT DISTINCT ON (topic_id) topic_id, user_id
        FROM posts
        WHERE deleted_at IS NULL AND post_type NOT IN (3, 4)
        ORDER BY topic_id, created_at DESC
      )
      UPDATE topics
      SET
        highest_post_number = visible_stats.highest_post_number,
        posts_count = visible_stats.posts_count,
        last_posted_at = visible_stats.last_posted_at,
        word_count = visible_stats.word_count,
        last_post_user_id = COALESCE(last_poster.user_id, topics.last_post_user_id)
      FROM visible_stats
      LEFT JOIN last_poster ON last_poster.topic_id = visible_stats.topic_id
      WHERE visible_stats.topic_id = topics.id
        AND topics.archetype <> 'private_message'
        AND (
          topics.highest_post_number <> visible_stats.highest_post_number OR
          topics.posts_count <> visible_stats.posts_count
        )
    SQL

    # Clamp topic_users.last_read_post_number to the new highest_post_number
    # where it now exceeds it (could happen from pretend_read of small action posts)
    execute <<~SQL
      UPDATE topic_users
      SET last_read_post_number = topics.highest_post_number
      FROM topics
      WHERE topic_users.topic_id = topics.id
        AND topic_users.last_read_post_number > topics.highest_post_number
        AND topics.archetype <> 'private_message'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
